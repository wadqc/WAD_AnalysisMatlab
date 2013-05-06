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

function WAD_resultsAppendFloat( level, value, variable, unit, description, limits, limits_field_name )
% Append number to WAD results object
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
%        limits   - struct with action limits, passed from config file
%        limits_field_name - name of action limit, should match the limits struct
%                   (e.g. 'SNR' to access limits.SNR.acceptable.lower etc)
%
% Output: to WAD.out.resultaten_floating, at end of analysis to be exported as XML
%
% It is acceptable to have empty data for parameters variable, unit,
% limits, limits_field_name
% 
% Note on action limits: in a future version of the WAD framework the
% action limit definitions should move to the web interface, and can then
% be removed from the configuration file.
%
% Limits XML template in configuration file, as part of <action>:
% <!-- ACTION LIMITS TEMPLATE
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
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-11-07 / JK
% first version
% ------------------------------------------------------------------------

% For access to out.results struct
global WAD

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

if ~isempty( description ), ...
    WAD.out.results{end}.omschrijving = description;
end


% Action limits
% These should go to the web interface in a future version!!
if ~isempty( limits ) && ~isempty( limits_field_name ) && isfield( limits, limits_field_name )
    lmts = limits.(limits_field_name);
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

