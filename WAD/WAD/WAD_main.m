% ------------------------------------------------------------------------
% This WAD folder provides a "library" of helper functions written for IQC.
% NVKF WAD IQC software is a framework for automatic analysis of DICOM objects.
% 
% Copyright 2012-2013  Joost Kuijer / jpa.kuijer@vumc.nl
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

function WAD_main( wadInputFileXML )
% Main routine to be called from the WAD framework (WAD_Processor)
%
% The WAD analysis module allows a configurable collection of submodules
% for analysis.
% 
% The main program performs the following tasks:
% - read the XML configuration file
% - read the XML input file
% - call WAD_runConfiguredAnalysis to look for series matching the
%   configured analysis, and call corresponding configured analysis
%   functions.
% - write the XML output file
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_main
%
% Depends:
% xml_io_tools by Jaroslaw Tuszynski
% http://www.mathworks.com/matlabcentral/fileexchange/12907-xmliotools
% See xml_io_tools_license.txt for license conditions.
%
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-08-06 / JK
% first WAD version named 0.95 converted from SQVID 0.95
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
my.name = 'WAD_main';
my.version = '1.0';
my.date = '20130910';

logfilename = 'WAD_analysis_log.txt'; % in output dir


% ----------------------
% initialize empty structs
% ----------------------
WAD.cfg = []; % configuration
WAD.in  = [];  % input file
WAD.results_index = 0; % global index number for all output types
WAD.out.results = []; % results array

% ----------------------
% read XML input file
% ----------------------
if nargin < 1
    disp( ['ERROR in ' my.name ' main program: missing WAD XML input file.'] );
    disp( ['Usage: ' my.name ' <XMLInputFile>'] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end

try
    WAD.in = xml_read( wadInputFileXML );
    % make sure .in exists
    if ~isfield( WAD, 'in' ), disp('Failed reading WAD input file'); end
catch err
    % not much we can do now, don't even know where to write log...
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot read WAD input file "' wadInputFileXML '"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% ----------------------
% check input for config file
% ----------------------
if ~isfield( WAD.in, 'analysemodule_cfg' )
    % this module needs a configuration file
    disp( ['ERROR in ' my.name ' main program: no configuration file.'] );
    disp( [my.name ' needs a configuration file!'] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% ----------------------
% read XML config file
% ----------------------
try
    WAD.cfg = xml_read( WAD.in.analysemodule_cfg );
    if ~isfield( WAD, 'cfg' ), error('Failed reading WAD_MR module config file'); end
catch err
    % not much we can do now
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot read WAD config file "' WAD.in.analysemodule_cfg '"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end


% ----------------------
% check / split ouput file/directory
% ----------------------
if ~isfield( WAD.in, 'analysemodule_output' )
    % we need an output file!
    disp( ['ERROR in ' my.name ' main program: no output file.'] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
end

% get the output directory
WAD.in.analysemodule_outputdir = fileparts( WAD.in.analysemodule_output );
% check if output directory exists
if ~isdir( WAD.in.analysemodule_outputdir )
    % cannot find it...
    disp( ['ERROR in ' my.name ' main program:'] );
    disp( ['Cannot find output directory "' WAD.in.analysemodule_output '".' ] );
    disp( ['Aborting ' my.name ' main program.'] );
    return
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
if isfield( WAD.cfg, 'name' )
    WAD_resultsAppendString( 2, WAD.cfg.name, 'Configuratie naam' );
end
if isfield( WAD.cfg, 'description' )
    WAD_resultsAppendString( 2, WAD.cfg.description, 'Configuratie beschrijving' );
end
if isfield( WAD.cfg, 'version' )
    if isnumeric( WAD.cfg.version ), WAD.cfg.version = num2str( WAD.cfg.version ); end
    WAD_resultsAppendString( 2, WAD.cfg.version, 'Configuratie versie' );
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

% write XML output file
try
    wPrefs = [];
    wPrefs.CellItem = false;
    %wPrefs.NoCells = 1;
    wPrefs.StructItem = true;
    xml_write( WAD.in.analysemodule_output, WAD.out, 'WAD', wPrefs );
    %type( WAD.in.analysemodule_output );
catch err
    disp( ['ERROR in ' my.name ' while writing results to XML file "' WAD.in.analysemodule_output '"'] );
    disp( err.message );
    disp( ['Aborting ' my.name ' main program.'] );
    WAD_vbprint( ['ERROR writing results to XML file "' WAD.in.analysemodule_output '"'] , 1 );
end

% close log file
if ( WAD.cfg.logverbose.fid > -1 )
    disp( 'Closing log file' );
    fclose( WAD.cfg.logverbose.fid );
end
