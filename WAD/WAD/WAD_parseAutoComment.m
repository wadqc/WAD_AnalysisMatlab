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

function WAD_parseAutoComment( sSeries, sAutoComment )
% - parse the <autoComment> field in configuration file
% - syntax:
% 	<autoComment>
% 	    <description>Scanner Software Version</description>
% 	    <field>SoftwareVersion<field>
%       <level>1<level>
% 	</autoComment>
% Takes the value from DICOM field SoftwareVersion and prints it as result
% in the defined level.
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_parseAutoComment
%
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-09-06 / JK
% V1.0: new function
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD


% version info
my.name = 'WAD_parseAutoComment';
my.version = '1.0';
my.date = '20130906';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'], 2 );


% sanity check
if isempty( sAutoComment )
    return
end

% number of comments in list
nComments = length( sAutoComment );

% read the DICOM image
ci = 1; % current instance: first image
WAD_vbprint( [my.name ':   loading DICOM image file: ' sSeries.instance(ci).filename ] );
try
    dcmInfo = dicominfo( sSeries.instance(ci).filename );
catch err
    WAD_ErrorMsg( my.name, ['ERROR reading DICOM info from file "' sSeries.instance(ci).filename '")'], err );
    return
end


% loop over comments
for i_ic = 1:nComments
    theDescription = []; % actually a valid description
    if isfield( sAutoComment(i_ic), 'description' )
        theDescription = sAutoComment(i_ic).description;
    end
    
    theLevel = 2; % default output to level 2 results
    if isfield( sAutoComment(i_ic), 'level' ) && ~isempty( sAutoComment(i_ic).level ) && isnumeric( sAutoComment(i_ic).level )
        theLevel = sAutoComment(i_ic).level;
    end
    
    if isfield( sAutoComment(i_ic), 'field' ) && ~isempty( sAutoComment(i_ic).field )
        theField = sAutoComment(i_ic).field;
        if isfield( dcmInfo, theField )
            theComment = [];
            
            if isstruct( dcmInfo.(theField) )
                % can't process structured data fields
            elseif ischar( dcmInfo.(theField) )
                theComment = dcmInfo.(theField);
            elseif isnumeric( dcmInfo.(theField) )
                theComment = num2str( dcmInfo.(theField) );
            end
            
            % do not export empty comment fields
            if isempty( theComment )
                WAD_vbprint( [my.name ': Error: field content of ' theField ' is not String or Numeric format, or DICOM field is empty.'] );
            else
                % output comment to results file
                WAD_resultsAppendString( theLevel, theComment, theDescription );
            end
            
        else
            % DICOM field not present
            WAD_vbprint( [my.name ': Error: no field named ' theField ' in DICOM header.'] );
        end
    end
end
