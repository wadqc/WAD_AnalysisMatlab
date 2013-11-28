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

function WAD_resultsAppendFloat( level, value, variable, unit, description, sLimits, limits_field_name )
% Append number to WAD results object
% V1.1: arguments sLimits and limits_field_name is optional, if omitted the action
% limits must be defined in new (V1.1) style in the module config file,
% see template below.
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_resultsAppendFloat
% 
% Input: level    - 1 or 2
%                   1 is intended for primary results ("front page table")
%                   2 for secondary (what went wrong with my analysis?)
%        value    - the result value (e.g. 94.6)
%        variable - what it is (e.g. 'diameter')
%        unit     - unit of the result (e.g. 'mm')
% OPTIONAL inputs from V1.1 onwards
%        sLimits   - struct with action limits, passed from config file
%        limits_field_name - name of action limit, should match the sLimits struct
%                   (e.g. 'SNR' to access sLimits.SNR.acceptable.lower etc)
%
%
% Output: to WAD.out.resultaten_floating, at end of analysis to be exported as XML
%
% It is acceptable to have empty data for parameters variable, unit,
% sLimits, limits_field_name
% 
% Note on action limits: in a future version of the WAD framework the
% action limit definitions should move to the web interface, and can then
% be removed from the configuration file.
%
% Limits XML template in configuration file, as part of <action>:
% <!-- ACTION LIMITS TEMPLATE OLD STYLE V1.0
% 	<limits>
% 	  <param_name>
% 		<acceptable>
% 		  <lower></lower>
% 		  <upper></upper>
% 		</acceptable>
% 		<critical>		
% 		  <lower></lower>
% 		  <upper></upper>
% 		</critical>
% 	    </param_name>
% 	</module_name>
% -->
%
% ------------------------------------------------------------------------
% NEW action limit template
% Defined at root level, NOT as part of <action>
% Version 1.1
% New: relative definition of limits now also possible.
% ------------------------------------------------------------------------
% 	<grens>
% 		<omschrijving>Combined coils</omschrijving>
% 		<grootheid>SNR</grootheid>
% 	    <grens_relatief_referentie>614</grens_relatief_referentie>
% 	    <grens_relatief_kritisch>20%</grens_relatief_kritisch>
% 	    <grens_relatief_acceptabel>10%</grens_relatief_acceptabel>
% 	</grens>
% 	<grens>
% 		<omschrijving>Row</omschrijving>
% 		<grootheid>Ghosting</grootheid>
% 		<eenheid>%</eenheid>
% 		<grens_kritisch_onder>0</grens_kritisch_onder>
% 		<grens_kritisch_boven>1</grens_kritisch_boven>
% 		<grens_acceptabel_onder>0</grens_acceptabel_onder>
% 		<grens_acceptabel_boven>0.5</grens_acceptabel_boven>
% 	</grens>
% 
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

% optional argument limits_field_name for backward compatibility V1.0
if nargin < 6
    limits_field_name = [];
    sLimits = [];
    limitStyleOld = false;
else
    limitStyleOld = true;
end

% For access to out.results and V1.1 action limits struct
global WAD

% Field name of array with action limits in config file
limitsFieldName = 'grens';

% version info
my.name = 'WAD_resultsAppendFloat';
my.version = '1.0';
my.date = '20121107';
% This module is called quite often, set verbose level 2
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'], 2 );


% WAD XML object
% WAD XML object
WAD.out.results{end+1} = []; % new item
% increase index number
WAD.results_index = WAD.results_index + 1;
WAD.out.results{end}.volgnummer = WAD.results_index;
WAD.out.results{end}.type     = 'float';
WAD.out.results{end}.niveau   = level;
WAD.out.results{end}.waarde   = value;

if ~isempty( variable ), ...
    WAD.out.results{end}.grootheid  = variable;
end

if ~isempty( unit ), ...
    WAD.out.results{end}.eenheid = unit;
end

% check if <resultsTag> was added for this action
if isfield( WAD, 'currentActionResultsNamePrefix' ) && ~isempty( WAD.currentActionResultsNamePrefix )
    description = [ WAD.currentActionResultsNamePrefix ' ' description ];
end
    
if ~isempty( description ), ...
    WAD.out.results{end}.omschrijving = description;
end


if limitStyleOld
    % Action limits V1.0
    % These should go to the web interface in a future version!!
    if ~isempty( sLimits ) && ~isempty( limits_field_name ) && isfield( sLimits, limits_field_name )
        lmts = sLimits.(limits_field_name);
        if isfield( lmts, 'acceptable' )
            if isfield( lmts.acceptable, 'lower' )
                WAD.out.results{end}.grens_acceptabel_onder = lmts.acceptable.lower;
            end
            if isfield( lmts.acceptable, 'upper' )
                WAD.out.results{end}.grens_acceptabel_boven = lmts.acceptable.upper;
            end
        end
        if isfield( lmts, 'critical' )
            if isfield( lmts.critical, 'lower' )
                WAD.out.results{end}.grens_kritisch_onder = lmts.critical.lower;
            end
            if isfield( lmts.critical, 'upper' )
                WAD.out.results{end}.grens_kritisch_boven = lmts.critical.upper;
            end
        end
    end

else
    % Action limits V1.1
    i_iLim = findLimits( limitsFieldName, variable, unit, description );
    if ~isempty( i_iLim )
        % We have a match, use the first match...
        lmts = WAD.cfg.(limitsFieldName)( i_iLim(1) );
        
        % Check if relative action limits are defined
        if isfield( lmts, 'grens_relatief_referentie' ) && ~isempty( lmts.grens_relatief_referentie )
            if isfield( lmts, 'grens_relatief_acceptabel' ) && ~isempty( lmts.grens_relatief_acceptabel )
                 relLim = parseRelativeLimit( lmts.grens_relatief_acceptabel, lmts.grens_relatief_referentie );
                 WAD.out.results{end}.grens_acceptabel_onder = relLim(1);
                 WAD.out.results{end}.grens_acceptabel_boven = relLim(2);
            end
            if isfield( lmts, 'grens_relatief_kritisch' ) && ~isempty( lmts.grens_relatief_kritisch )
                 relLim = parseRelativeLimit( lmts.grens_relatief_kritisch, lmts.grens_relatief_referentie );
                 WAD.out.results{end}.grens_kritisch_onder = relLim(1);
                 WAD.out.results{end}.grens_kritisch_boven = relLim(2);
            end
        end
                
        % Write any existing action limits to results (overwrites relative limits)
        if isfield( lmts, 'grens_acceptabel_onder' ) && ~isempty( lmts.grens_acceptabel_onder )
            WAD.out.results{end}.grens_acceptabel_onder = lmts.grens_acceptabel_onder;
        end
        if isfield( lmts, 'grens_acceptabel_boven' ) && ~isempty( lmts.grens_acceptabel_boven )
            WAD.out.results{end}.grens_acceptabel_boven = lmts.grens_acceptabel_boven;
        end
        if isfield( lmts, 'grens_kritisch_onder' ) && ~isempty( lmts.grens_kritisch_onder )
            WAD.out.results{end}.grens_kritisch_onder = lmts.grens_kritisch_onder;
        end
        if isfield( lmts, 'grens_kritisch_boven' ) && ~isempty( lmts.grens_kritisch_boven )
            WAD.out.results{end}.grens_kritisch_boven = lmts.grens_kritisch_boven;
        end
    end
end
end % function



% Local helper functions
function i_iLim = findLimits( limitsFieldName, variable, unit, description )
% Find configured limits matching variable / unit / description of current result

    global WAD % for access to WAD.cfg

    % Check if any limits defined
    i_iLim = [];
    if ~isempty( WAD.cfg ) && isfield( WAD.cfg, limitsFieldName ) && ~isempty( WAD.cfg.(limitsFieldName) )

        % We should have some limits defined...
        sLimits = WAD.cfg.(limitsFieldName);

        % Another check: need at least one item defined of variable / unit / description
        if ( isfield( sLimits, 'grootheid' ) || isfield( sLimits, 'eenheid' ) || isfield( sLimits, 'omschrijving' ) ) ...
            && ( ~isempty( variable ) || ~isempty( unit ) || ~isempty( description ) )

            % Find match of grootheid/eenheid/omschrijving with action limit
            if ~isempty( variable ) && isfield( sLimits, 'grootheid' )
                cmp1 = strcmp( variable, {sLimits.grootheid} );
            else
                cmp1 = true;
            end

            if ~isempty( unit ) && isfield( sLimits, 'eenheid' )
                cmp2 = strcmp( unit, {sLimits.eenheid} );
            else
                cmp2 = true;
            end

            if ~isempty( description ) && isfield( sLimits, 'omschrijving' )
                cmp3 = strcmp( description, {sLimits.omschrijving} );
            else
                cmp3 = true;
            end

            i_iLim = find( cmp1 & cmp2 & cmp3 );
        end
    end
end % findLimits( )


function limits = parseRelativeLimit( theLimit, theReference )
% Parse relative limit, formatted as percentage (10%) or offset (number)
    
    % check for '%' character
    if strfind( theLimit, '%')
        tmp = textscan( theLimit, '%f', 'delimiter', '%' );
        relLim = tmp{1} / 100.0;
        limits(1) = ( 1.0 - relLim ) .* theReference;
        limits(2) = ( 1.0 + relLim ) .* theReference;
    else
        limits(1) = theReference - theLimit;
        limits(2) = theReference + theLimit;
    end
end % parseRelativeLimit( )
