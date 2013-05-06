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

function WAD_vbprint_init( logfilename )
% vbprint is used for tracing / debugging / logging
% where the text output goes to, is defined by WAD.cfg.logverbose
% init: check XML fields and open log file

global WAD

default.mode = 1;
default.level = 1;

% check logverbose configuration fields
if ~isfield( WAD.cfg, 'logverbose' )
    WAD_resultsAppendString( 2, 'Field logverbose missing in configuration file. Using default settings.', 'WARNING' );
    % apply default settings
    WAD.cfg.logverbose = default;
end

if ~isfield( WAD.cfg.logverbose, 'mode' )
    WAD_resultsAppendString( 2, 'Field logverbose.mode missing in configuration file. Using default settings.', 'WARNING' );
    % apply default settings
    WAD.cfg.logverbose.mode = default.mode;
end
if ~isfield( WAD.cfg.logverbose, 'level' )
    WAD_resultsAppendString( 2, 'Field logverbose.level missing in configuration file. Using default settings.', 'WARNING' );
    % apply default settings
    WAD.cfg.logverbose.level = default.level;
end


% open log file
WAD.cfg.logverbose.fid = -1;
WAD.cfg.logverbose.fullfile = fullfile( WAD.in.analysemodule_outputdir, logfilename );
WAD.cfg.logverbose.fid = fopen( WAD.cfg.logverbose.fullfile, 'w' );
if WAD.cfg.logverbose.fid < 0
    % error opening the file
    WAD_resultsAppendString( 2, ['Could not open log file "' WAD.cfg.logverbose.fullfile '"'], 'ERROR' );
    return
end

return
