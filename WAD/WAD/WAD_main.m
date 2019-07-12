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

function WAD_main( varargin )
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
% Version 1.0.1 20140116
% Bugfix in WAD_findMatchingSeries:matchDicomTag
% - stop if DICOM file cannot be read
% - check numeric type for print in logfile (creates corrupted text file
%   which is not displayed by through web interface)
% ------------------------------------------------------------------------
% Version 2.0 20170707
% Compatible with WAD2
% ------------------------------------------------------------------------


% ----------------------
% defines
% ----------------------
% version info
my.name = 'WAD_main';
my.version = '2.0';
my.date = '20170707';


% ----------------------
% check for WAD1 or WAD2 style command line
% WAD1 syntax: WAD.exe <XMLInputFile>
% WAD2 syntax: WAD.exe  -c <config.json> -d <study_data_folder> -r <results.json>
% ----------------------
if nargin == 1

    % ----------------------
    % should be WAD1
    % ----------------------
    wadInputFileXML = varargin{1};
    WAD1_main( wadInputFileXML );
    return

elseif nargin >= 6

    % ----------------------
    % should be WAD2
    % ----------------------
    % check for compulsory options -c -d -r
    k = 1;
    while k < size(varargin,2)
        switch varargin{k} 
            case '-c'
                cmdarg.config_json = varargin{k+1};
                k = k + 2;
            case '-r'
                cmdarg.results_json = varargin{k+1};
                k = k + 2;
            case '-d'
                cmdarg.studyDataDir = varargin{k+1};
                k = k + 2;
            otherwise
                disp( ['ERROR in ' my.name ' main program: unknown command line argument ' varargin{k} ] );
                disp( ['Usage [WAD1 syntax]: ' my.name ' <XMLInputFile>'] );
                disp( ['Usage [WAD2 syntax]: ' my.name ' -c <config.json> -d <study_data_folder> -r <results.json>'] );
                disp( ['Aborting ' my.name ' main program.'] );
                return
        end
    end
    
    % check if all compulsory commandline arguments were present
    % and call WAD2 main routine
    if isfield( cmdarg, 'config_json' ) && isfield( cmdarg, 'results_json' ) && isfield( cmdarg, 'studyDataDir' )
        WAD2_main( cmdarg );
        return
    end
    
end


% Error message
disp( ['ERROR in ' my.name ' main program: missing command line arguments.'] );
disp( ['Usage [WAD1 syntax]: ' my.name ' <XMLInputFile>'] );
disp( ['Usage [WAD2 syntax]: ' my.name ' -c <config.json> -d <study_data_folder> -r <results.json>'] );
disp( ['Aborting ' my.name ' main program.'] );
return


