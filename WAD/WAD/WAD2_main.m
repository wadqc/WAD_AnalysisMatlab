% ------------------------------------------------------------------------
% This WAD folder provides a "library" of helper functions written for IQC.
% NVKF WAD IQC software is a framework for automatic analysis of DICOM objects.
% 
% Copyright 2012-2017  Joost Kuijer / jpa.kuijer@vumc.nl
% 
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ------------------------------------------------------------------------

function WAD2_main( cmdarg )
% Main routine to be called from the WAD framework (WAD_Processor)
%
% Version 2.0 20170707
% Compatible with WAD2
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
% WAD provides access to
% - input file
% - configuration file
% - output/results
% - constants, these may be defined in modality specific wrappers
global WAD


% ----------------------
% defines
% ----------------------
% version info
my.name = 'WAD2_main';
my.version = '2.0';
my.date = '20170707';

logfilename = 'WAD_analysis_log.txt'; % in output dir

% executable that creates WAD1-style input file
% reason for external exe: older Matlab versions are slow reading DICOM
% headers.
dicomScannerName = 'wad2_dicomscanner.py';


% ----------------------
% initialize empty structs
% ----------------------
WAD.versionmodus = 2; % WAD1 or WAD2 style input/output
WAD.cfg = []; % configuration
WAD.in  = [];  % input file
WAD.results_index = 0; % global index number for all output types
WAD.out.results = []; % results array


% ----------------------
% input/results file from command line
% ----------------------
WAD.in.analysemodule_cfg = cmdarg.config_json;
WAD.in.analysemodule_output = cmdarg.results_json;
WAD.in.studyDataDir = cmdarg.studyDataDir;
% In WAD2 the output directory is the current working directory
% which actually is a temporary directory and is cleaned up after import
% into the database.
WAD.in.analysemodule_outputdir = pwd();



% ----------------------
% read JSON config file
% ----------------------
try
    WAD.cfg = loadjson( WAD.in.analysemodule_cfg );
    if ~isfield( WAD, 'cfg' ), error('Failed reading WAD_MR module config file'); end
catch err
    % not much we can do now
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot read WAD config file "' WAD.in.analysemodule_cfg '"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% get the output directory
% check if output directory exists
if ~isdir( WAD.in.analysemodule_outputdir )
    % cannot find it...
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot find output directory "' WAD.in.analysemodule_output '".' ] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end

% if configured create copy of the output dir for debug purposes
try
    if ~isempty( WAD.cfg.actions.logverbose.params.copyOutputDir )
        disp( [my.name ': you have configured a copy of the module output directory for debugging purposes.'] );
        disp( [my.name ': name of source directory = "' WAD.in.analysemodule_outputdir '"'] );
        disp( [my.name ': name of copied directory = "' WAD.cfg.actions.logverbose.params.copyOutputDir '"'] );
        cmdstr = ['cp -r ' WAD.in.analysemodule_outputdir ' ' WAD.cfg.actions.logverbose.params.copyOutputDir ];
        disp( [my.name ': issuing system cmd "' cmdstr '"' ] );
        status = system( cmdstr );
        if status ~= 0
            disp( ['ERROR in ' my.name ' main program:'] );
            disp( ['Error copying output dir for debugging purposes.'] );
        end
    end
catch err
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Error copying output dir for debugging purposes.'] );
    disp( err.message );
end    


% ----------------------
% initialize logfile
% ----------------------
WAD_vbprint_init( logfilename );
WAD_vbprint( ['Starting ' my.name ' Version ' my.version ' (' my.date ') at ' datestr( now, 'yyyy-mm-dd HH:MM:SS' ) ] );
WAD_vbprint( ['Config file: "' WAD.in.analysemodule_cfg '"'] );
% dump module config to logfile
if WAD.cfg.logverbose.fid ~= -1
    gen_object2file( WAD.cfg.logverbose.fid, WAD.cfg );
end


% ----------------------
% config info to level 2 results
% ----------------------
if isfield( WAD.cfg, 'author' )
    WAD_resultsAppendString( 2, WAD.cfg.name, 'Configuration author' );
end
if isfield( WAD.cfg, 'creator' )
    WAD_resultsAppendString( 2, WAD.cfg.creator, 'Configuration creator' );
end
if isfield( WAD.cfg, 'description' )
    WAD_resultsAppendString( 2, WAD.cfg.description, 'Configuration description' );
end
if isfield( WAD.cfg, 'version' )
    if isnumeric( WAD.cfg.version ), WAD.cfg.version = num2str( WAD.cfg.version ); end
    WAD_resultsAppendString( 2, WAD.cfg.version, 'Configuration version' );
end


% ----------------------
% scan dicom files and create WAD1-style input file
% ----------------------
% locate Python exe
dcmscnr = which(dicomScannerName);
if isempty( dcmscnr )
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( [ dicomScannerName ' was not found.'] );
    disp( ['Cannot execute Python scan of DICOM files'] );
    disp( ['Aborting ' my.name ' main program.'] );
    WAD_vbprint( ['ERROR: ' dicomScannerName ' was not found.'], 1 );
    return
end

% run the indexing scan
tic
syscmd = ['python ' dcmscnr ' ' WAD.in.studyDataDir];
disp( ['Start scanning DICOM files: "' syscmd '"' ] );
[status, out] = system( syscmd );
disp( out )
toc
if status ~= 0
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Error while scanning DICOM input files'] );
    disp( ['Aborting ' my.name ' main program.'] );
    WAD_vbprint( ['ERROR while scanning DICOM input files.'], 1 );
    return
end

% read the json input file
try
    WAD.in.patient = loadjson( 'input.json' );
    if ~isfield( WAD.in, 'patient' ), error('Failed reading WADlab json input file'); end
catch err
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot read input file "input.json"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end
% WAD1 compatibility
WAD.in.patient.id = 'WAD2_dummyPatientID';
WAD.in.patient.name = 'WAD2_dummyPatientName';


% WAD1 compatibility: convert cell arrays to matrix arrays
try
    % series level
    WAD.in.patient.study.series = cell2mat( WAD.in.patient.study.series );
    % loop over series
    for i_icSeries = 1:size(WAD.in.patient.study.series,2)
        % instance level 
        WAD.in.patient.study.series(i_icSeries).instance = cell2mat( WAD.in.patient.study.series(i_icSeries).instance );
    end
catch err
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Error converting series/instances from cell arrays to matrix arrays.'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% ----------------------
% run the analysis
% - call WAD_runConfiguredAnalysis to look for series matching the
%   configured analysis, and call corresponding configured analysis
%   functions.
% ----------------------
try
    WAD_runConfiguredAnalysis;
catch err
    disp( ['ERROR in ' my.name ' during image analysis.'] );
    disp( err.message );
    for i=1:length( err.stack )
        disp( ['File: ' err.stack(i).file '  Function: ' err.stack(i).name '  Line: ' num2str(err.stack(i).line)] );
    end
    disp( ['Aborting ' my.name ' main program.'] );
    WAD_vbprint( 'ERROR during image analysis.', 1 );
end


% ----------------------
% finish
% ----------------------
% link log file to output, fullfile was set by WAD_vbprint_init()
WAD_resultsAppendObject( 2, logfilename, 'Log file' );

% write JSON output file
try
    savejson( '', WAD.out.results, WAD.in.analysemodule_output );
    %type( WAD.in.analysemodule_output );
catch err
    disp( ['ERROR in ' my.name ' while writing results to JSON file "' WAD.in.analysemodule_output '"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    WAD_vbprint( ['ERROR writing results to JSON file "' WAD.in.analysemodule_output '"'] , 1 );
end

% close log file
if ( WAD.cfg.logverbose.fid > -1 )
    disp( 'Closing log file' );
    fclose( WAD.cfg.logverbose.fid );
end

% time stamp
toc


% for debug purposes: give me copy of the final directory
try
    if ~isempty( WAD.cfg.actions.logverbose.params.copyOutputDir )
        disp( [my.name ': you have configured a copy of the module output directory for debugging purposes.'] );
        disp( [my.name ': name of source directory = "' WAD.in.analysemodule_outputdir '"'] );
        disp( [my.name ': name of copied directory = "' WAD.cfg.actions.logverbose.params.copyOutputDir '"'] );
        cmdstr = ['cp -r ' WAD.in.analysemodule_outputdir ' ' WAD.cfg.actions.logverbose.params.copyOutputDir '_final' ];
        disp( [my.name ': issuing system cmd "' cmdstr '"' ] );
        status = system( cmdstr );
        if status ~= 0
            disp( ['ERROR in ' my.name ' main program:'] );
            disp( ['Error copying output dir for debugging purposes.'] );
        end
    end
catch err
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Error copying output dir for debugging purposes.'] );
    disp( err.message );
end    

