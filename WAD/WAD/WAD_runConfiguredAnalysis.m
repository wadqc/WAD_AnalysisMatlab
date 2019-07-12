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

function WAD_runConfiguredAnalysis
% Runs configured analysis modules
%
% - Check format of configured actions in configuration XML
% - Find series that match the configured criteria
% - Run the configured analysis
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_runConfiguredAnalysis
%
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-11-06 / JK
% first WAD version named 0.95 converted from SQVID 0.95
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-09-06 / JK
% V1.0: <match> is now optional. If not defined, action is always run.
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-09-06 / JK
% V1.1: - Produce message for v1.0 style action limits
%       - Support for configurable action field <resultsNamePrefix> to
%         allow configuration of a single analysis function in multiple
%         actions, and still get unique identifiers in the results
%         database.
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 20170712 / JK
% V2.0: - WAD2 compatible
% ------------------------------------------------------------------------
% 2018100312 / JK
% allow surrogate DICOM tag ImagesInSeries
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
global WAD

% version info
my.name = 'WAD_runConfiguredAnalysis';
my.version = '2.1';
my.date = '20181003';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'], 2 );


% WAD1/2 compatibility
% WAD2 uses 'actions' as fieldname, WAD1 uses 'action'
if isfield( WAD.cfg, 'actions' )
    WAD.cfg.action = cell2mat( struct2cell( WAD.cfg.actions ) );
    fn = fieldnames( WAD.cfg.actions );
    % WAD2 has action name as field name, WAD1 has action name in .name
    for i_icAction = 1:length( WAD.cfg.action )
        WAD.cfg.action( i_icAction ).name = fn{ i_icAction };
    end
end

if ~isfield( WAD.cfg, 'action' )
    % no actions defined
    WAD_vbprint( [my.name ': no actions defined, check your configuration file!'], 1 );
    return
end

% shortcut access to current study
curStudy = WAD.in.patient(1).study(1);


% WAD2 defines AcquisitionDateTime result:
% {
%   "name": "AcquisitionDateTime",
%   "category": "datetime",
%   "val": "2015-01-13 10:53:54"
% },
if WAD.versionmodus > 1
    try
        % take date time from first image
        WAD_vbprint( [my.name ': getting date/time from image ' curStudy.series(1).instance(1).filename ], 1 );
        dcminfo = dicominfo( curStudy.series(1).instance(1).filename );
        WAD_resultsAppendDateTime( dcminfo.StudyDate, dcminfo.StudyTime )
    catch err
        WAD_ErrorMsg( my.name, ['ERROR getting studydate/time from first DICOM image.'], err );
        return
    end
end


% ----------------------
% loop over configured actions
% ----------------------
i_nAction = length( WAD.cfg.action );
WAD_vbprint( [my.name ': number of configured actions = ' num2str(i_nAction)], 1 );
WAD_vbprint( [my.name ': starting loop over configured analysis'], 2 );

for i_icAction = 1:i_nAction
    WAD_vbprint( [my.name ': checking action ' num2str(i_icAction)], 2 );
    % shortcut access to current action
    curAct = WAD.cfg.action( i_icAction );
    
    % output some debugging info
    WAD_vbprint( [my.name ': action name = "' curAct.name '"' ], 2 );
    
    % --------------------
    % check "name" field
    % --------------------
    if ~isfield( curAct, 'name' )
        WAD_vbprint( [my.name ' ERROR: "name" is not defined for action ' num2str(i_icAction)], 1 );
        continue % next action
    end
    % check if function (in a .m file) with configured name exists
    if exist( curAct.name, 'file' ) ~= 2
        % funtion does not exist
        WAD_vbprint( [my.name ' in action ' num2str(i_icAction) ': cannot find analysis function named "' curAct.name '"' ], 1 );
        continue % next action
    end
    % construct function handle
    curAct.fh = str2func( curAct.name );
    
    % --------------------
    % check "match" field
    % --------------------
    % WAD1/2 compatibility: WAD2 has match field in params, WAD1 in action
    if ~isfield( curAct, 'match' ) && isfield( curAct, 'params' ) && isfield( curAct.params, 'match' ) && ~isempty( curAct.params.match )
        % should be WAD2, multiple match criteria separated by ;
        match = textscan(curAct.params.match, '%s', 'Delimiter', ';');
        % the array we want is in the first cell
        match = match{1}';
        
        matchStr = []; % just for informative text output
        % loop over match criteria
        for i_icM = 1:length( match )
            singleMatch = match{i_icM};
            % look for match criterium that starts with @ (meaning match with specific DICOM field)
            if singleMatch(1) == '@'
                % match with DICOM field
                % format : @<DICOM field name>=<field content>
                % example: '@ImageType=ORIGINAL\PRIMARY\GDC'
                % skip first @ character
                matchDcm = textscan( singleMatch(2:end), '%s', 'Delimiter', '=');
                % the array we want is in the first cell
                matchDcm = matchDcm{1}';
                % it should have length 2, first is field name, second is content to match with
                if length( matchDcm ) ~= 2
                    WAD_vbprint( [my.name ': ERROR reading match criterium "' singleMatch '"' ] );
                    continue
                end
                % copy to WAD1-type xml-read struct
                curAct.match{i_icM}.ATTRIBUTE.type = 'DICOM';
                curAct.match{i_icM}.ATTRIBUTE.field = matchDcm{1};
                curAct.match{i_icM}.CONTENT = matchDcm{2};
            else
                % match with SeriesDescription DICOM field
                if length( match ) == 1
                    curAct.match = singleMatch;
                else
                    curAct.match{i_icM} = singleMatch;
                end
            end
            
            matchStr = [ matchStr '"' singleMatch '" ' ];
        end
        WAD_vbprint( [my.name ': Found configured match criteria = ' matchStr] );
        
        
        % WAD2 has optional items type and field in fields matchType and matchField
        %if isfield( curAct.params, 'matchType' )
    end

    if ~isfield( curAct, 'match' ) || isempty( curAct.match )
        % Change V1.0: not considered an error, repair with empty match.
        % Empty match results in match with any series.
        %WAD_vbprint( [my.name ' ERROR: "match" is not defined for action ' num2str(i_icAction) ' ' curAct.name], 1 );
        %continue % next action
        curAct.match = [];
    end
    % check match definition
    [curAct.match, validMatch] = WAD_checkMatchDefinition( curAct.match );
    % continue with next action if match definition is not valid
    if ~validMatch, continue; end % next action
    
    % --------------------
    % check "params" field
    % --------------------
    if ~isfield( curAct, 'params' )
        % not considered an error, repair with empty params
        curAct.params = [];
    end

    % --------------------
    % check "resultsNamePrefix" field
    % option to configure a prefix for the result 'description'
    % --------------------
    % WAD2: in params field
    if isfield( curAct.params, 'resultsNamePrefix' ) && ~isempty( curAct.params.resultsNamePrefix )
        % WAD2 style prefix
        curAct.resultsNamePrefix = curAct.params.resultsNamePrefix;
    end
    if ~isfield( curAct, 'resultsNamePrefix' )
        curAct.resultsNamePrefix = [];
    end

    % Need to communicate this to WAD_resultsAppendFloat( )...
    % Not the best solution on earth but works for single thread. If the
    % for-loop around this part of code would ever be changed to parfor
    % then this would not work!
    if ~isempty( curAct.resultsNamePrefix )
        WAD_vbprint( [my.name ' in action ' num2str(i_icAction) ': resultsTag was set to "' curAct.resultsNamePrefix '" for action "' curAct.name '"' ], 1 );
    end
    WAD.currentActionResultsNamePrefix = curAct.resultsNamePrefix;
    
    % --------------------
    % check "limits" field
    % Note: not present for v1.1 style action limits
    % Use of curAct.limits is depreciated from v1.1 onwards, remove
    % next lines of code in future version.
    % --------------------
    if ~isfield( curAct, 'limits' )
        % v1.1: new style action limits are not defined within the action.
        curAct.limits = [];
    end

    % ----------------------
    % find series that matches with current action
    % and run action if a match is found
    % ----------------------
    WAD_findMatchingSeries( curStudy, curAct )
    
    % ----------------------
    % Reset any results tagging actions
    % ----------------------
    WAD.currentActionResultsNamePrefix = [];
    
end % loop over actions
