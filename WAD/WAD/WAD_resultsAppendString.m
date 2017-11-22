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

function WAD_resultsAppendString( level, value, description )
% Append text string to WAD results object
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_resultsAppendString
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
% 2013-11-26 / JK
% V2.1  - Added support for passing a "criterium" defined in the config
%         file, similar to float action limits.
% 	<grens>
% 		<omschrijving>Fase-coderingsrichting</omschrijving>
% 		<criterium>ROW</criterium>
% 	</grens>
% ------------------------------------------------------------------------
% 2017-07-17 / JK / WAD2
% ------------------------------------------------------------------------


global WAD

WAD_vbprint( 'Module WAD_resultsAppendString()', 2 );

if WAD.versionmodus < 2

    % ------------------------------------------------------------------------
    % WAD 1 XML object
    % ------------------------------------------------------------------------
    % Field name of array with action limits in config file
    limitsFieldName = 'grens';

    WAD.out.results{end+1} = []; % new item
    % increase index number
    WAD.results_index = WAD.results_index + 1;
    WAD.out.results{end}.volgnummer = WAD.results_index;
    WAD.out.results{end}.type = 'char';
    WAD.out.results{end}.niveau = level;
    WAD.out.results{end}.waarde = value;

    % check if <resultsTag> was added for this action
    if isfield( WAD, 'currentActionResultsNamePrefix' ) && ~isempty( WAD.currentActionResultsNamePrefix )
        if ~isempty( description )
            description = [ WAD.currentActionResultsNamePrefix ' ' description ];
        else
            description = WAD.currentActionResultsNamePrefix;        
        end
    end

    if ~isempty( description ), WAD.out.results{end}.omschrijving = description; end

    i_iLim = findLimits( limitsFieldName, description );
    if ~isempty( i_iLim )
        % We have a match, use the first match...
        lmts = WAD.cfg.(limitsFieldName)( i_iLim(1) );

        % Check if relative action limits are defined
        if isfield( lmts, 'criterium' ) && ~isempty( lmts.criterium )
            WAD.out.results{end}.criterium = lmts.criterium;
        end
    end

    %gen_object_display( handles.WAD );

else
    
    % ------------------------------------------------------------------------
    % WAD 2 JSON object
    % ------------------------------------------------------------------------
    WAD.out.results{end+1} = []; % new item
    % increase index number
    WAD.results_index = WAD.results_index + 1;
    %WAD.out.results{end}.volgnummer = WAD.results_index;
    WAD.out.results{end}.category = 'string';
    %WAD.out.results{end}.niveau = level;
    WAD.out.results{end}.val = value;

    % check if <resultsTag> was added for this action
    if isfield( WAD, 'currentActionResultsNamePrefix' ) && ~isempty( WAD.currentActionResultsNamePrefix )
        if ~isempty( description )
            description = [ WAD.currentActionResultsNamePrefix ' ' description ];
        else
            description = WAD.currentActionResultsNamePrefix;        
        end
    end

    WAD.out.results{end}.name = description;
    %WAD.out.results{end}.name = ['param' num2str(WAD.results_index)];


end

end



% Local helper functions
function i_iLim = findLimits( limitsFieldName, description )
% Find configured limits matching variable / unit / description of current result
% Adapted from the AppendFloat version

    global WAD % for access to WAD.cfg

    % Check if any limits defined
    i_iLim = [];
    if ~isempty( WAD.cfg ) && isfield( WAD.cfg, limitsFieldName ) && ~isempty( WAD.cfg.(limitsFieldName) )

        % We should have some limits defined...
        sLimits = WAD.cfg.(limitsFieldName);

        % Another check: need at least one item defined of variable / unit / description
        if isfield( sLimits, 'omschrijving' ) && ~isempty( description )

            % Find match of grootheid/eenheid/omschrijving with action limit
            if ~isempty( description ) && isfield( sLimits, 'omschrijving' )
                cmp3 = strcmp( description, {sLimits.omschrijving} );
            else
                cmp3 = true;
            end

            i_iLim = find( cmp3 );
        end
    end
end % findLimits( )
