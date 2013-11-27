% ------------------------------------------------------------------------
% WAD_MG is a mammography analysis module written for IQC.
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

function WAD_MG_flatField( i_iSeries, sSeries, sParams )
% Implementation of the program flatfield.exe as distributed by EUREF.
% The MG image is subdevided into square ROI's, and for each ROI the mean
% and variance are calculated. Then the pixels deviating more than a certain
% percentage from the ROI mean are counted (details exported to calculation
% log). Finally the mean and variance of all ROI's are averaged to get the
% overall image mean, SD and SNR.
% 
% ------------------------------------------------------------------------
% WAD MG
% file: WAD_MG_flatField
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2009-10-09 / JK
% first version
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-08-14 / JK
% Adapted to WAD framework
% ------------------------------------------------------------------------
% 20131127 / JK
% Support new (v1.1) style action limits
% ------------------------------------------------------------------------


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MG_flatField';
my.version = '1.1';
my.date = '20131127';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% display dialogs and figures on screen?
isInteractive = false;

% image number?
ci = 1;

% limit of number of deviating pixels
maxNumPix = 200;


% load image
fname = sSeries.instance(ci).filename;
WAD_vbprint( [my.name ':   reading DICOM image: ' fname ] );
info = dicominfo( fname );
img = dicomread( info );

szImg = size( img );

% testcase: set region with low SNR
%RR = uint16(randn(50,50) .* 25);
%img(3001:3050,1001:1050) = img(3001:3050,1001:1050) + RR(:,:);

% pixel size
szPxX_mm = info.PixelSpacing(2);
szPxY_mm = info.PixelSpacing(1);

% ROI size in mm
szROI_mm = 10;

% ROI size in pixels
szROIX_px = floor( szROI_mm ./ szPxX_mm );
szROIY_px = floor( szROI_mm ./ szPxY_mm );

% ROI shift over half its size
RoiShiftX_px = floor( szROIX_px ./ 2 );
RoiShiftY_px = floor( szROIY_px ./ 2 );


% output some info
WAD_vbprint( [my.name ':   Pixel size: ' num2str(szPxX_mm) ' x ' num2str(szPxY_mm) ' mm'] );
WAD_vbprint( [my.name ':   ROI size  : ' num2str(szROI_mm) ' mm (square)'] );
WAD_vbprint( [my.name ':   ROI size  : ' num2str(szROIX_px) ' x ' num2str(szROIY_px) ' pixels'] );

% skip configured number of ROW's at beginning and end
% this depends on the detector.
skipRows = 'auto';
if isfield( sParams, 'skipRows' ) && ~isempty( sParams.skipRows ) && isnumeric( sParams.skipRows ) && ( sParams.skipRows >= 0 )
    skipRows = sParams.skipRows;
    WAD_vbprint( [my.name ':   Skipping ' num2str(skipRows) ' rows at start and end.'] );
end
% check if autodetection is needed
if isequal( skipRows, 'auto' )
    % autodetect number of rows to skip
    % collapse cols
    mean4skipRows = mean( img, 2 );
    % threshols at mean centre value times 2
    %thres4skipRows = mean( mean4skipRows( end/4:end/4*3 ) ) .* 2;
    % locate rows above threshold
    %rowsToSkip = find( mean4skipRows > thres4skipRows )
    % find first deviating pixel
    skipRows = -1;
    diff4skipRows = diff(mean4skipRows);
    for i_ic = 1:length( diff4skipRows )
        if diff4skipRows(i_ic) ~= 0
            skipRows = i_ic;
            break;
        end
    end
    % check if we found anything
    if skipRows ~= -1
        WAD_vbprint( [my.name ':   Autodetected number of rows to skip: ' num2str(skipRows) '.'] );
    else
        WAD_vbprint( [my.name ':   Autodetection of number of rows to skip failed. Aborting flatfield analysis.'] );
        return
    end
end


nRoiX = floor(  szImg(2)               ./ RoiShiftX_px ) - 1;
nRoiY = floor( (szImg(1) - 2*skipRows) ./ RoiShiftY_px ) - 1;

% init struct to combine per-ROI calculations
roi.nRoi    = 0;
roi.sumMean = 0;
roi.sumVar  = 0;
roi.devPixX = [];
roi.devPixY = [];
roi.devPixValue = [];
roi.devPixRoiMean = [];
roi.nDevPix = 0;
roi.SNR = 0;

% basic check
if (nRoiX == 0) || (nRoiY == 0)
    myErrordlg( isInteractive, 'ROI is larger than image. Not calculating Flatflield.', 'FlatField', 'on' );
    WAD_vbprint( [my.name ':   ROI is larger than image. Not calculating Flatflield.'] );
    return
end

% set threshold for deviating pixels
if isfield( sParams, 'threshold' ) && ~isempty( sParams.threshold )
    roi.threshold = sParams.threshold; % threshold for deviating pixels
    WAD_vbprint( [my.name ':   Threshold for deviating pixels set at ' num2str(roi.threshold*100) '%.'] );
else
    % no threshold defined, not calculating deviating pixels
    roi.threshold = 0;
    WAD_vbprint( [my.name ':   No threshold for deviating pixels (parameter threshold) configured, not calculating deviating pixels.'] );
end    

% set threshold for deviating ROIs (in terms of SNR
if isfield( sParams, 'SNRthreshold' ) && ~isempty( sParams.SNRthreshold )
    SNRthreshold = sParams.SNRthreshold; % threshold for deviating ROIs
    WAD_vbprint( [my.name ':   Threshold for deviating SNR of ROIs set at ' num2str(SNRthreshold*100) '%.'] );
else
    % no threshold defined, not calculating deviating pixels
    SNRthreshold = 0;
    WAD_vbprint( [my.name ':   No threshold for deviating ROIs (parameter SNRthreshold) configured, not calculating deviating ROIs.'] );
end    


% display a waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating FlatField' ); end
WAD_vbprint( [my.name ':   Calculating FlatField...'] );


% global mean / SD / SNR
theMean = mean2( img( 1+skipRows:end-skipRows , : ) );
SD   = std2 ( img( 1+skipRows:end-skipRows , : ) );
SNR  = theMean ./ SD;

% pre-allocate arrays for ROI position and SNR
roiSNRsx = zeros(nRoiY+1,nRoiX+1);
roiSNRsy = zeros(nRoiY+1,nRoiX+1);
roiSNR   = zeros(nRoiY+1,nRoiX+1);

% loop over ROI's
for ix = 1:nRoiX+1
    % update waitbar
    if isInteractive, waitbar( ix/(nRoiX+1), h ); end

    for iy = 1:nRoiY+1
        if ix > nRoiX
            % last column
            roi.ex = szImg(2); % end index of ROI
            roi.sx = roi.ex - szROIX_px + 1; % start index
        else            
            roi.sx = (ix-1) * RoiShiftX_px + 1; % start index
            roi.ex = roi.sx + szROIX_px; % end index of ROI
        end
        if iy > nRoiY
            % last row
            roi.ey = szImg(1) - skipRows; % end index of ROI
            roi.sy = roi.ey - szROIY_px + 1; % start index
        else        
            roi.sy = skipRows + (iy-1) * RoiShiftY_px + 1; % start index
            roi.ey = roi.sy + szROIY_px; % end index of ROI
        end
        % copy coordinates of current ROI
        roiSNRsx(iy,ix) = roi.sx;
        roiSNRsy(iy,ix) = roi.sy;
        
        % evaluate ROI
        roi = calcFlatFieldRoi( img( roi.sy:roi.ey, roi.sx:roi.ex ), roi, maxNumPix );
        % copy SNR of current ROI
        roiSNR(iy,ix)   = roi.SNR;
        
        % check on large number of deviating pixels found, if so probably
        % something is wrong with the skipRows setting and the analysis
        % will virtually hang because it takes ages to sieve and sort...
        if roi.nDevPix >= maxNumPix
            WAD_vbprint( [my.name ':   WARNING: Found ' num2str(roi.nDevPix) ' potential deviating pixels, maximum number reached; stopped searching.'] );
            break; % escape from inner loop...
        end
    end
    % ... and escape from outer loop
    if roi.nDevPix >= maxNumPix, break, end
end


% in case a threshold for deviating pixels was set...
if roi.threshold > 0
    WAD_vbprint( [my.name ':   Found ' num2str(length(roi.devPixX)) ' potential deviating pixels, starting sorting and sieving.'] );
    % sort and sieve the double counted deviating pixels (ROI's overlap!)
    [devPixX, indx] = sort( roi.devPixX );
    devPixY       = zeros( size ( roi.devPixY       ) );
    devPixValue   = zeros( size ( roi.devPixValue   ) );
    devPixRoiMean = zeros( size ( roi.devPixRoiMean ) );
    for i=1:length(devPixX)
        devPixY(i)       = roi.devPixY(indx(i));
        devPixValue(i)   = roi.devPixValue(indx(i));
        devPixRoiMean(i) = roi.devPixRoiMean(indx(i));
    end
    % find double counted pixels
    nPix = length(devPixX);
    ignorePix = zeros( nPix, 1 );
    if isInteractive, waitbar( 0, h, 'Sorting and sieving deviating pixels'); end
    for i=1:nPix-1
        % update waitbar
        if isInteractive, waitbar( i/(nPix), h ); end
        % skip pixels already marked to be ignored
        if ~ignorePix(i)
            % check all pixels with same X coordinate
            j = 1;
            while (i+j<=nPix) && (devPixX(i)==devPixX(i+j))
                % check for equal Y coordinate
                if devPixY(i)==devPixY(i+j)
                    % same coordinates... ignore!
                    ignorePix(i+j) = 1;
                end
                % check next one
                j=j+1;
            end
        end
    end
    nSievedDevPix = length(find(~ignorePix));
end

% export results, only averaged ROI SNR and number of deviating pixels goes into results database
roi.mean = roi.sumMean ./ roi.nRoi;
roi.SD   = sqrt( roi.sumVar ./ roi.nRoi );
SNR_ROI  = roi.mean ./ roi.SD;
if roi.threshold > 0
    numDeviatingPix = nSievedDevPix;
end

% in case a threshold for deviating ROIs was set...
if SNRthreshold > 0
    % find deviating ROIs
    thrhi = SNR_ROI * ( 1 + SNRthreshold );
    thrlo = SNR_ROI * ( 1 - SNRthreshold );
    % above high threshold
    [roiSNRrow,roiSNRcol] = find( roiSNR > thrhi );
    % below low threshold
    [tmprow,tmpcol] = find( roiSNR < thrlo );
    % put them together
    roiSNRrow = [ roiSNRrow; tmprow ];
    roiSNRcol = [ roiSNRcol; tmpcol ];
    numDeviatingRoi = length( roiSNRrow );
end


% output results to logfile
WAD_vbprint( [my.name ':   GLOBAL'] );
WAD_vbprint( [my.name ':   Mean = ' num2str(theMean)] );
WAD_vbprint( [my.name ':   SD   = ' num2str(SD)] );
WAD_vbprint( [my.name ':   SNR  = ' num2str(SNR)] );
WAD_vbprint( [my.name ':   ROI (average)'] );
WAD_vbprint( [my.name ':   Mean = ' num2str(roi.mean)] );
WAD_vbprint( [my.name ':   SD   = ' num2str(roi.SD)] );
WAD_vbprint( [my.name ':   SNR  = ' num2str(SNR_ROI)] );
if roi.threshold > 0
    WAD_vbprint( [my.name ':   numDeviatingPix = ' num2str(numDeviatingPix)] );
end
if SNRthreshold > 0
    WAD_vbprint( [my.name ':   numDeviatingRoi = ' num2str(numDeviatingRoi)] );
end

% close waitbar
if isInteractive, close(h), end

% write results
WAD_resultsAppendString( 2, ['Analysis on series ' num2str( sSeries.number ) ' - image ' num2str(ci)], 'Flatfield' );
% global stats
WAD_resultsAppendFloat( 1, theMean, 'Mean', [], 'Flatfield Global' );
WAD_resultsAppendFloat( 1, SD, 'SD', [], 'Flatfield Global' );
WAD_resultsAppendFloat( 1, SNR, 'SNR', [], 'Flatfield Global' );
% ROI stats
WAD_resultsAppendFloat( 2, roi.mean, 'Mean', [], 'Flatfield ROI' );
WAD_resultsAppendFloat( 2, roi.SD, 'SD', [], 'Flatfield ROI' );
WAD_resultsAppendFloat( 1, SNR_ROI, 'SNR', [], 'Flatfield ROI' );

% report stuff related to deviating pixels only if threshold was defined
if roi.threshold > 0
    WAD_resultsAppendString( 2, ['Threshold for deviating pixels set at ' num2str(roi.threshold*100) '%.'], 'Flatfield' );
    WAD_resultsAppendFloat( 1, numDeviatingPix, 'Deviating', 'pixels', 'Flatfield Deviating Pixels' );

    % write deviating pixel coordinates to calculation log file
    WAD_resultsAppendString( 2, 'Deviating pixels (Coordinates in pixels starting at top-left corner)', 'Flatfield' );
    WAD_resultsAppendString( 2, 'X      Y   value  ROI mean', 'Flatfield' );
    % and sieve ignored (double) pixels
    sievedDevPixX = zeros( nSievedDevPix, 1 );
    sievedDevPixY = zeros( nSievedDevPix, 1 );
    j=0;
    for i=1:nPix
        if ~ignorePix(i)
            j=j+1;
            sievedDevPixX(j) = devPixX(i);
            sievedDevPixY(j) = devPixY(i);
            % write to calculations log file
            coordtxt = sprintf( '%6.0f %6.0f %6.0f %6.2f', devPixX(i), devPixY(i), devPixValue(i), devPixRoiMean(i) );
            WAD_resultsAppendString( 2, coordtxt, 'Flatfield' );
            % also write to log file
            WAD_vbprint( [my.name ':   ' coordtxt] );
        end
    end

    % create a plot with deviating pixels
    % create figure
    quiet = true;
    if quiet 
        fig_visible = 'off';
    else
        fig_visible = 'on';
    end

    hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Deviating Pixels' );
    %hFig = figure( 'Visible', fig_visible, 'Name', 'Deviating Pixels' );
    colormap(gray);
    % display image 
    % - reduce image size: show only one in imDispPx pixels
    % - with +/- 4 SD full scale mapping
    imDispPx = 5;
    imshow( img(1:imDispPx:end,1:imDispPx:end), [theMean-4*SD theMean+4*SD] );
    axis image
    axis square
    axis off
    title(['series ' num2str(sSeries.number) ' - image ' num2str(sSeries.instance(ci).number) ' (1 in ' num2str(imDispPx.^2) ' pixels displayed)'], 'Interpreter', 'none');
    hold on
    
    % overlay of deviating ROIs
    if SNRthreshold > 0
        for i=1:numDeviatingRoi
            rectangle('Position', [ roiSNRsx( roiSNRrow(i), roiSNRcol(i) ), ...
                                    roiSNRsy( roiSNRrow(i), roiSNRcol(i) ), ...
                                    szROIX_px, szROIY_px ] ./ imDispPx, 'LineWidth',1, 'EdgeColor','b' )
        end
    end
    
    % overlay of deviating pixels
    plot( sievedDevPixX/imDispPx, sievedDevPixY/imDispPx, 'r.', 'MarkerSize', 20 )

    % flatfield figure is a primary result
    WAD_resultsAppendFigure( 1, hFig, 'flatfield', 'Flatfield' );
    if quiet
        % delete non-visible image
        delete( hFig );
    end
    
else % deviating pixels were not calculated...
    WAD_resultsAppendString( 2, 'Threshold for deviating pixels was not defined, no deviating pixels calculated.', 'Flatfield' );
end


if SNRthreshold > 0
    WAD_resultsAppendString( 2, ['Threshold for deviating ROIs set at ' num2str(SNRthreshold*100) '%.'], 'Flatfield' );
    WAD_resultsAppendFloat( 1, numDeviatingRoi, 'Deviating', 'ROIs', 'Flatfield Deviation ROI' );
else % deviating ROIs were not calculated...
    WAD_resultsAppendString( 2, 'Threshold for deviating ROIs was not defined, no deviating ROIs calculated.', 'Flatfield' );
end




% -----------------------------------------------------------------------
% local funtion: calcFlatFieldRoi( pixdata, roi, mx_nPix )
%
% - calculates mean sum, variance and deviating pixels of pixdata
% - updates roi data structure
% -----------------------------------------------------------------------
function roi = calcFlatFieldRoi( pixdata, roi, mx_nPix )

roi.nRoi    = roi.nRoi + 1;
% basic statistics
roimean = mean2( pixdata );
roistd  = std2 ( pixdata );
roi.sumMean = roi.sumMean + roimean;
roi.sumVar  = roi.sumVar  + roistd.^2 ;
% ROI SNR
roi.SNR = roimean ./ roistd;


% output first ROI (basic testing)
% if roi.nRoi == 1
%     roi.sx
%     roi.sy
%     roimean
%     sqrt( var( pixdata(:) ) )
%     %pixdata(:)
% end

if roi.threshold > 0
    % find deviating pixels
    thrhi = roimean * ( 1 + roi.threshold );
    thrlo = roimean * ( 1 - roi.threshold );
    % above high threshold
    [row,col] = find( pixdata > thrhi );
    % store coordinates of pixels
    for i=1:length(row)
        if roi.nDevPix >= mx_nPix, break, end
        roi.nDevPix = roi.nDevPix + 1;
        % pixdata is a subset of image, so need to add ROI start coordinates
        roi.devPixX(roi.nDevPix) = col(i) + roi.sx - 1;
        roi.devPixY(roi.nDevPix) = row(i) + roi.sy - 1;
        roi.devPixValue(roi.nDevPix) = pixdata(row(i),col(i));
        roi.devPixRoiMean(roi.nDevPix) = roimean;
    end
    % below low threshold
    [row,col] = find( pixdata < thrlo );
    % store coordinates of pixels
    for i=1:length(row)
        if roi.nDevPix >= mx_nPix, break, end
        roi.nDevPix = roi.nDevPix + 1;
        % pixdata is a subset of image, so need to add ROI start coordinates
        roi.devPixX(roi.nDevPix) = col(i) + roi.sx - 1;
        roi.devPixY(roi.nDevPix) = row(i) + roi.sy - 1;
        roi.devPixValue(roi.nDevPix) = pixdata(row(i),col(i));
        roi.devPixRoiMean(roi.nDevPix) = roimean;
    end
end
