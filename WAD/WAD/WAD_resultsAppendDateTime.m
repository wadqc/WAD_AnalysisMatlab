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

function WAD_resultsAppendDateTime( theDate, theTime )
% Append datetime string to WAD results object
% Input is DICOM formatted date and time.
% Date: '20171208'
% Time: '081638'
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_resultsAppendDateTime
%
% {
%   "name": "AcquisitionDateTime",
%   "category": "datetime",
%   "val": "2015-01-13 10:53:54"
% },
%
% ------------------------------------------------------------------------
% 2017-07-17 / JK / WAD2
% ------------------------------------------------------------------------


global WAD

WAD_vbprint( 'Module WAD_resultsAppendDateTime()', 2 );

if WAD.versionmodus > 1
   
    % ------------------------------------------------------------------------
    % WAD 2 JSON object
    % ------------------------------------------------------------------------
    WAD.out.results{end+1} = []; % new item
    % increase index number
    WAD.results_index = WAD.results_index + 1;
    %WAD.out.results{end}.volgnummer = WAD.results_index;
    WAD.out.results{end}.category = 'datetime';
    %WAD.out.results{end}.niveau = level;
    
    % Get DICOM formatted date / time into WAD2 format
    datetimestr = [ theDate(1:4) '-' theDate(5:6) '-' theDate(7:8) ' ' theTime(1:2) ':'  theTime(3:4) ':'  theTime(5:6) ];
    WAD.out.results{end}.val = datetimestr;

    WAD.out.results{end}.name = 'AcquisitionDateTime';

end

end

