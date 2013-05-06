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

function [newMatch, valid] = WAD_checkMatchDefinition( match )
% Check format of <match> field in config xml
%
% valid formats are:
% <match>
%
% <match field="SeriesDescription" | "ImagesInSeries">
%
% <match type="DCM4CHEE" field="SeriesDescription" | "ImagesInSeries">
%
% <match type="DICOM" field="MatlabDicomFieldName"> where
%   MatlabDicomFieldName is replaced by the actual DICOM field name in
%   the Matlab DICOM info struct.
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_checkMatchDefinition
%
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-11-06 / JK
% first WAD version named 0.95 converted from SQVID 0.95
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD


% version info
my.name = 'WAD_checkMatchDefinition';
my.version = '0.95';
my.date = '20121106';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'], 2 );

valid = false;

% --------------------
% check match definition
% --------------------
% this is pretty nasty: for a single match entry, match
% is a string, but for multiple entries, match is a cell
% array!
matchClass = class( match );
switch matchClass
    case 'char'
        WAD_vbprint( [my.name ': <match> is a char array.'], 2 )
        i_nMatch = 1;
    case 'cell'
        WAD_vbprint( [my.name ': <match> is a cell array.'], 2 )
        i_nMatch = length( match );
    case 'struct'
        WAD_vbprint( [my.name ': <match> is a struct array.'], 2 )
        i_nMatch = length( match );
    otherwise
        WAD_vbprint( [my.name ': ERROR: <match> field has not been converted to cell/struct/char array. Check the config xml file!'] )
        valid = false;
        return
end


valid = true;
% loop over matches (in the cell / struct array)
for i_icMatch = 1:i_nMatch
    switch matchClass
        case 'char'
            % use the string
            curMatch = match;
        case 'cell'
            % use one item of cell array
            curMatch = match{ i_icMatch };
        case 'struct'
            % use one item of struct array
            curMatch = match( i_icMatch );
        otherwise
            % should not happen... was already tested above.
            WAD_vbprint( [my.name ': ERROR unknown class when copying match'] )
            valid = false;
            return
    end

    % force various match format variants into a fixed template stucture:
    %
    % match.ATTRIBUTE.type = 'DCM4CHEE' | 'DICOM'
    % match.ATTRIBUTE.field = <fieldname>
    % match.CONTENT = <content>
    %
    if ~isfield( curMatch, 'ATTRIBUTE' )
        % no attributes were set, default type and field
        tmpContent = curMatch; % move this to CONTENT field.
        curMatch = [];
        curMatch.ATTRIBUTE.type = 'DCM4CHEE';
        curMatch.ATTRIBUTE.field = 'SeriesDescription';
        curMatch.CONTENT = tmpContent;
    else
        % attributes were set, check contents
        if ~isfield( curMatch.ATTRIBUTE, 'type' )
            % no type was set, use default type
            curMatch.ATTRIBUTE.type = 'DCM4CHEE';
        end

        % type is defined, check if content is valid
        switch curMatch.ATTRIBUTE.type
            case 'DCM4CHEE'
                % check field for DCM4CHEE type
                if isfield( curMatch.ATTRIBUTE, 'field' )
                    % for now, only a limited number of options are supported
                    if ~any( strcmp( curMatch.ATTRIBUTE.field, {'SeriesDescription', 'ImagesInSeries'} ) )
                        WAD_vbprint( [my.name ' ERROR: currently only fields "SeriesDescription" or "ImagesInSeries" are supported.' num2str(i_icAction) ' ' curAct.name], 1 );
                        WAD_vbprint( [my.name ' field = "' curAct.field '" for action ' num2str(i_icAction) ' ' curAct.name], 1 );
                        valid = false; break;
                    end
                else
                    % no field for DCM4CHEE was set, set default SeriesDescription 
                    curMatch.ATTRIBUTE.field = 'SeriesDescription';
                end

            case 'DICOM'
                % check field for DICOM type, field definition is compulsory
                if ~isfield( curMatch.ATTRIBUTE, 'field' )
                    WAD_vbprint( [my.name ' ERROR: match for ' num2str(i_icAction) ' ' curAct.name ' is DICOM type without field attribute.'], 1 );
                    WAD_vbprint( [my.name 'Match with DICOM field requires a field name. Set field="FieldName" attribute in configuration file.' ], 1 );
                    valid = false; break;
                end

            otherwise
                WAD_vbprint( [my.name ' ERROR: currently only "match" attribute types "DICOM" or "DCM4CHEE" are supported.' num2str(i_icAction) ' ' curAct.name], 1 );
                WAD_vbprint( [my.name ' match = "' curMatch '" for action ' num2str(i_icAction) ' ' curAct.name], 1 );
                valid = false; break;
        end % switch type

    end % if attributes defined

    % copy modified match contents back to i/o match variable
    switch matchClass
        case 'char'
            newMatch = curMatch;
        case 'cell'
            newMatch{ i_icMatch } = curMatch;
        case 'struct'
            newMatch( i_icMatch ) = curMatch;
        otherwise
            % should not happen... was already tested above.
            WAD_vbprint( [my.name ': ERROR unknown class for copy back to match.'] )
            valid = false;
            return
   end
end % loop over matches
