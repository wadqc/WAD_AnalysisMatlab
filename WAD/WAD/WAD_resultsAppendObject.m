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

function WAD_resultsAppendObject( level, filename, description )
% Append text string to WAD results object
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_resultsAppendObject
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-11-07 / JK
% first version
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-11-26 / JK
% V1.1  - New style XML definition of action limit in config file.
%         Old style definition still supported.
%       - Support for configurable action field <resultsNamePrefix> to
%         allow configuration of a single analysis function in multiple
%         actions, and still get unique identifiers in the results
%         database.
% ------------------------------------------------------------------------

global WAD

WAD_vbprint( 'Module WAD_resultsAppendObject()', 2 );

% WAD XML object
WAD.out.results{end+1} = []; % new item
WAD.results_index = WAD.results_index + 1;
WAD.out.results{end}.volgnummer = WAD.results_index;
WAD.out.results{end}.type = 'object';
WAD.out.results{end}.niveau = level;
% object file path and name, fullfile() works on all platforms
% (Windows/Linux)
WAD.out.results{end}.object_naam_pad = fullfile( WAD.in.analysemodule_outputdir, filename );

% check if <resultsTag> was added for this action
if isfield( WAD, 'currentActionResultsNamePrefix' ) && ~isempty( WAD.currentActionResultsNamePrefix )
    description = [ WAD.currentActionResultsNamePrefix ' ' description ];
end

if ~isempty( description ), ...
    WAD.out.results{end}.omschrijving = description;
end

end
