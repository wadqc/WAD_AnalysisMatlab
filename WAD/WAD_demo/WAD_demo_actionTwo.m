% ------------------------------------------------------------------------
% WAD_MR is an MRI analysis module written for IQC.
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

function WAD_demo_actionTwo( i_iSeries, sSeries, sParams, sLimits )
% Get some parameters from the DICOM header
% 
% Input
% - i_iSeries: the actual SeriesNumber (source: XML input file)
% - sSeries: structure with actual series information as parsed from the
%   XML input file. Check the input file what is actually in there.
% - sParams: structure with the parameter fields defined in the
%   configuration file for this action. If not defined in config, sParams
%   is empty [].
% - sLimits: stucture with action limits defined in the configuration file
%   for this action. If not defined in config, sLimits is emptry [].
%
% Note that the full input file structure may be accessed through the
% global variable WAD.in
%
% Output: written via WAD_resultsAppend*() interface
%
% ------------------------------------------------------------------------
% WAD demo
% file: WAD_demo_actionOne
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2013-09-05 / JK
% first version
% ------------------------------------------------------------------------

% version info
my.name = 'WAD_demo_actionTwo';
my.version = '1.0';
my.date = '20130905';

% output to log file (object at results level 2)
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );

% A switch to show the images on screen during testing, but allows easy
% switch off for release version.
% Use quiet = true for release version!
quiet = true;

% ----------------------
% GLOBALS
% ----------------------
% if you defined anything in WAD_demo.m or need to use WAD.in
% otherwise you may remove the next line...
%global WAD



% read dicom header of first image of series
WAD_vbprint( [my.name ':   Reading DICOM header: ' sSeries.instance(1).filename ] );
try
    img = dicomread( sSeries.instance(1).filename );
catch err
    WAD_ErrorMsg( my.name, ['ERROR reading DICOM info from file "' sSeries.instance(1).filename '")'], err );
    return
end


% calculate something from that data
meanSignal = mean2( img );
relStdSignal_percent  = std2( img ) ./ meanSignal * 100;

% You may use the string type result to create a heading in the table
WAD_resultsAppendString( 1, [], 'Image Statistics' );


% Now write the numbers and define which action limits are related
% WAD_resultsAppendFloat( level, value, variable, unit, description, limits, limits_field_name )
% Note that the last argument refers to the field name in sLimits, and
% should match the name in the action limit definition in the config XML.
WAD_resultsAppendFloat( 1, meanSignal           , 'Mean'       , [] , 'Signal', sLimits, 'SignalMean'  );
WAD_resultsAppendFloat( 1, relStdSignal_percent , 'Relative SD', '%', 'Signal', sLimits, 'SignalRelSD' );

% Action limit example for XML config:
% 	<limits>
% 	  <SignalMean>  <!-- This tag should match with the limits_field_name in WAD_resultsAppendFloat -->
% 		<acceptable>
% 		    <lower>100</lower>
% 		    <upper>200</upper>
% 		</acceptable>
% 		<critical>		
% 		    <lower>50</lower>
% 		    <upper>250</upper>
% 		</critical>
% 	  </SignalMean>  <!-- This tag should match with the limits_field_name in WAD_resultsAppendFloat -->
% 	  <SignalRelSD>  <!-- This tag should match with the limits_field_name in WAD_resultsAppendFloat -->
% 		<acceptable>
% 		    <lower>5</lower>
% 		    <upper>10</upper>
% 		</acceptable>
% 		<critical>		
% 		    <lower>0</lower>
% 		    <upper>20</upper>
% 		</critical>
% 	  </SignalRelSD>  <!-- This tag should match with the limits_field_name in WAD_resultsAppendFloat -->
% 	</limits>


% Just another example: result is simply a number
aNumber = 42;
WAD_resultsAppendFloat( 2, aNumber, 'Distance', 'mm', 'Phantom', [], [] );


% Include some figures as well
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end

% Example of parameter use: define a configurable ROI
% In the config file define
% 	  <params>
% 	    <!-- ROI definition, pixel index starts with 1 (not 0) -->
% 	    <Xmin>32</Xmin>
% 	    <Xmax>64</Xmax>
% 	    <Ymin>60</Ymin>
% 	    <Ymax>80</Ymax>
%     </params>
% 

% Define some default values
imgsize = size( img );
% Default ROI is full image
Xmin = 1; Xmax = imgsize(2);
Ymin = 1; Ymax = imgsize(1);

% Check if parameters were defined and check ranges too!
% Note that params are optional in the config file.
if isfield( sParams, 'Xmin' ) && ~isempty( sParams.Xmin )
    Xmin = max( sParams.Xmin, Xmin);
end
if isfield( sParams, 'Xmax' ) && ~isempty( sParams.Xmax )
    Xmax = min( sParams.Xmax, Xmax);
end
if isfield( sParams, 'Ymin' ) && ~isempty( sParams.Ymin )
    Ymin = max( sParams.Ymin, Ymin);
end
if isfield( sParams, 'Ymax' ) && ~isempty( sParams.Ymax )
    Ymax = min( sParams.Ymax, Ymax);
end

% some diagnostic info to level 2 results
WAD_resultsAppendString( 2, ['X=' num2str(Xmin) ':' num2str(Xmax) ' Y=' num2str(Ymin) ':' num2str(Ymax)], 'ROI definition' );

% copy the ROI out of the image
theImage = img( Ymin:Ymax, Xmin:Xmax );

% create figure
hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Image ROI' );
colormap(gray);
imagesc( theImage );
axis image
axis square
axis off
title('Your Image Title Here', 'Interpreter', 'none');

% Export the figure a result (object) at results level 2
% WAD_resultsAppendFigure( level, handle, tag, description )
% - tag should be a unique string within this module, it is a prefix
%   for the image file name
% - description is shown below the image in on the results page
WAD_resultsAppendFigure( 2, hFig, 'roi', 'ROI Pixel Data' );

% delete non-visible image
if quiet 
    delete( hFig );
end




% another plot though not very related to the actual image data...
t = 0 : 0.01 : 2;
s = sin( pi .* t.^2 );

hFig2 = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Nice Plot' );
plot( t, s );
title('Your Image Title Here', 'Interpreter', 'none');

% Export the figure a result (object) at results level 1
WAD_resultsAppendFigure( 1, hFig2, 'justAnotherPlot', 'Sine Plot' );

% delete non-visible image
if quiet 
    delete( hFig2 );
end


return
