% ------------------------------------------------------------------------
% WAD_MR is an MRI analysis module written for WAD-QC software.
% NVKF WAD-QC software is a framework for automatic analysis of DICOM objects.
% 
% Copyright 2012-2015  Joost Kuijer / jpa.kuijer@vumc.nl
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

function WAD_MR_FMRI_weisskoff( i_iSeries, sSeries, sParams )
% FMRI-specific QC procedures on EPI images
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_FMRI_weisskoff
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2010-11-10 / JK
% first version
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2015-11-02 / JK
% adapted to WAD
% ------------------------------------------------------------------------
% Implementation of QC tests for fMRI purposes:
% Relevant references:
% - Lee Friedman and Gary H. Glover. Report on a Multicenter fMRI Quality
%   Assurance Protocol. J Magn Res Imag 23:827�839 (2006)
% - Weisskoff RM. Simple measurement of scanner stability for functional NMR
%   imaging of activation in the brain. Magn Reson Med 1996;36:643-645
% - Bodurka et al, ISMRM 14 (2006), p. 1094
%
% ------------------------------------------------------------------------
% Optional parameters:
% 	<params>
%	    <!-- welk beeld (slice nummer) te gebruiken? -->
%	    <!-- toegestaan: <nummmer>, firstInSeries, lastInSeries -->
%	    <image>1</image>
%       <roisize>20</roisize>
%       <WK_MxRoisize>20</WK_MxRoisize>
%       <detrendOrder>5</detrendOrder>
%       <nVolumesToSkip>2</nVolumesToSkip>
%       <innerLoop></innerLoop>
% 	</params>
% ------------------------------------------------------------------------
% 2017-01-11 / JK
% replaced imshow() by imagesc(); imshow produces error when in Linux
% called from WAD-Processor running as a service (without a display).
% ------------------------------------------------------------------------



%% version info
my.name = 'WAD_MR_FMRI_weisskoff';
my.version = '0.3.1';
my.date = '20170111';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% produce a figure on the screen or be quiet...
quiet = true;
isInteractive = false;

if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end



%% Parameters
% <roisize>
% ROI size for detrending and summary statistics (SNR, FSNR etc)
if isfield( sParams, 'roisize' ) && ~isempty( sParams.roisize )
    roisize = sParams.roisize;
else
    roisize = 20; % default ROI size
end

% max ROI size for Weisskoff plot
if isfield( sParams, 'WK_MxRoisize' ) && ~isempty( sParams.WK_MxRoisize )
    WK_MxRoisize = sParams.WK_MxRoisize;
else
    WK_MxRoisize = 20; % default ROI size
end

% detrending: order of polynomal fit
if isfield( sParams, 'detrendOrder' ) && ~isempty( sParams.detrendOrder )
    detrendOrder = sParams.detrendOrder;
else
    detrendOrder = 5; % default detrend order
end

% initial volumes (measurements, acquisitions, samples, whatever you like to call them) to skip
if isfield( sParams, 'nVolumesToSkip' ) && ~isempty( sParams.nVolumesToSkip )
    nVolumesToSkip = sParams.nVolumesToSkip;
else
    nVolumesToSkip = 2; % default volumes to skip
end
WAD_vbprint( ['Skipping first ' num2str(nVolumesToSkip) ' volumes.'] );

% ordering of slice-time loop
if isfield( sParams, 'innerloop' ) && ~isempty( sParams.innerloop )
    switch sParams.innerloop
        case 'auto'
            innerloopIsAuto = true;
        case 'time'
            innerloopIsAuto  = false;
            innerloopIsSlice = false;
        case 'slice'
            innerloopIsAuto  = false;
            innerloopIsSlice = true;
        otherwise
            WAD_vbprint( ['WARNING: configured innerloop value ' sParams.innerloop ' is invalid, using auto.'] );
            innerloopIsAuto = true;            
    end
else
    % use default: auto
    innerloopIsAuto = true;
end    


%% Check input images
% list of instance numbers
instanceNumber = [sSeries.instance(:).number];
nImages = length( instanceNumber );
WAD_vbprint( ['Number of images: ' num2str(nImages) ] );

% sort instances to instance number
[ sorted_nums, instanceNumSortedIndex ] = sort( instanceNumber );

% Probe first image
infoFirst = dicominfo( sSeries.instance( instanceNumSortedIndex(1) ).filename );

nVolumesTotal = infoFirst.NumberOfTemporalPositions;
nVolumes = nVolumesTotal - nVolumesToSkip;

if mod( nImages, nVolumesTotal )
    WAD_vbprint( 'Warning: FMRI number of images not a multiple of number of volumes.' );
    myWarndlg( isInteractive, 'Number of images not a multiple of number of volumes', 'FMRI', 'on' );
end

nSlices = floor( nImages ./ nVolumesTotal );
WAD_vbprint( [ 'Number of slices: ' num2str(nSlices) ] );


%% Slice to analyse; default is mid slice
if isfield( sParams, 'image' ) && ~isempty( sParams.image )
    switch sParams.image
        case {'midslice', 'auto'}
            iSlice = ceil( nSlices / 2.0 );
        case WAD.const.firstInSeries
            iSlice = 1;
        case WAD.const.lastInSeries
            iSlice = nSlices;
        otherwise
            iSlice = sParams.image;
    end
else
    % use default; mid slice
    iSlice = ceil( nSlices / 2.0 );
end

% check validity
if ~isnumeric(iSlice)
    WAD_vbprint( [ 'Warning: configured slice number "' iSlice '" is invalid. Using default (mid slice)' ] );
    iSlice = ceil( nSlices / 2.0 );
elseif iSlice < 1 || iSlice > nSlices
    WAD_vbprint( [ 'Warning: configured slice number ' num2str(iSlice) ' is invalid. Using default (mid slice)' ] );
    iSlice = ceil( nSlices / 2.0 );
end

WAD_vbprint( [ 'Analyzing slice number: ' num2str(iSlice) ] );


% Check: non-square images not tested yet...
if infoFirst.Width ~= infoFirst.Height
    WAD_vbprint( 'Error: non-square image matrix not supported yet.' );
    myErrordlg( isInteractive, 'Sorry: non-square image matrix not supported yet.', 'FMRI', 'on' );
    return
end


%% Read images (or create data when in simulation mode)
% Allocate space for images
WAD_vbprint( [ 'Allocating space for images: ' num2str(nVolumes) ' x ' num2str(infoFirst.Height) ' x ' num2str(infoFirst.Width) ] );
imgs = zeros( nVolumes, infoFirst.Height, infoFirst.Width );


SIMULATIONMODE = false;

if SIMULATIONMODE
    % generate random noise dataset
    % Noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
    % TSRNn = n * SNR / { sqrt( 1 + (n*lambda*SNR) ^2 ) }
    simuSignal = 5000;
    simuSNR = 250;
    simuLambda = 0.0002;
    imgs = simuSignal ./ simuSNR * randn(size(imgs)) + simuSignal;
    for v=1:nVolumes
        imgs(v,:,:) = imgs(v,:,:) + simuLambda * simuSignal * randn(1,1);
    end
else
    % read input data from DICOM images
    if innerloopIsAuto
        vendor = infoFirst.Manufacturer;
        WAD_vbprint( ['Manufacturer = ' vendor ] );

        switch vendor
            case {'GE MEDICAL SYSTEMS', 'SIEMENS', 'TOSHIBA'}
                % Siemens / GE / Toshiba give all slices of a volume
                WAD_vbprint('Siemens / GE / Toshiba slice/time order.');
                innerloopIsSlice = true;
            case {'Philips Medical Systems'}
                % Philips give all time points of a slice
                WAD_vbprint('Philips slice/time order.');
                innerloopIsSlice = false;
            otherwise
                WAD_vbprint('WARNING: Unknown manufacturer. Cannot determine slice/time ordering of images.');
                WAD_vbprint('         Using default: all slices per time point (GE/Siemens/Toshiba).');
                innerloopIsSlice = true;            
        end
    else
        WAD_vbprint(['Using configured slice/time order; innerloop = ' sParams.innerloop ]);
    end

    % display waitbar in interactive mode
    if isInteractive, h = waitbar( 0, 'Reading images...' ); end

    % loop over images
    i_icVol = 1;
    if innerloopIsSlice
        for i_icNum = iSlice + nVolumesToSkip*nSlices : nSlices : nImages
            % read image
            imgs( i_icVol, : , : ) = dicomread( sSeries.instance( instanceNumSortedIndex(i_icNum) ).filename );
            i_icVol = i_icVol + 1;
            % update waitbar
            if isInteractive, waitbar( i_icNum / nImages, h ); end
        end
    else
        for i_icNum = 1 + (iSlice-1)*nVolumesTotal + nVolumesToSkip : (iSlice)*nVolumesTotal
            % read image
            imgs( i_icVol, : , : ) = dicomread( sSeries.instance( instanceNumSortedIndex(i_icNum) ).filename );
            i_icVol = i_icVol + 1;
            % update waitbar
            if isInteractive, waitbar( i_icNum / nVolumes, h ); end
        end    
    end
    
    % close waitbar in interactive mode
    if isInteractive, close( h ), end
end

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating...' ); end

WAD_resultsAppendString( 1, '---------', '--- Weisskoff test ---' )
WAD_resultsAppendString( 2, '---------', '--- Weisskoff test ---' )

WAD_vbprint( ['Skipping first ' num2str(nVolumesToSkip) ' volumes.'] );
WAD_resultsAppendFloat( 2, nVolumesToSkip, 'volumes skipped', [], 'Volumes' );


%% ROI detrending and summary statistics
WAD_vbprint( ['Fitted polynomal order for detrending: ' num2str(detrendOrder)] )
WAD_resultsAppendFloat( 2, detrendOrder, 'polynomal fit order', [], 'Detrending' );

% square ROI for summary statistics
WAD_vbprint( ['ROI size for summary statistics: ' num2str(roisize) ' pixels'] )
WAD_resultsAppendFloat( 2, roisize, 'size', 'pixels', 'ROI' );

i_iRoiX = floor( (infoFirst.Width -roisize)/2 )+1 : ceil( (infoFirst.Width +roisize)/2 ); % index
i_iRoiY = floor( (infoFirst.Height-roisize)/2 )+1 : ceil( (infoFirst.Height+roisize)/2 ); % index

% Detrending of ROI time series
% time series of mean signal in ROI
timeseriesRoiSignal = mean( mean( imgs( :, i_iRoiY, i_iRoiX ), 3), 2);
% detrending with polynomal fit
time_s = (0:nVolumes-1)' .* infoFirst.RepetitionTime ./ 1000;
[detrendCoeff, ~, muScale] = polyfit( time_s, timeseriesRoiSignal , detrendOrder);
detrendVal = polyval( detrendCoeff, time_s, [], muScale );

% trend is max difference in signal between start and end
% trend expressed as percentage of mean signal
ROI_trend_percent = ( max(detrendVal) - min(detrendVal) ) ./ mean( timeseriesRoiSignal ) * 100;
WAD_vbprint( ['ROI trend      : ' num2str(ROI_trend_percent) ' %'] );
WAD_resultsAppendFloat( 1, ROI_trend_percent, 'trend', '%', 'ROI' );

% fluctuation is SD of residual after detrending
ROI_fluctuation = std( timeseriesRoiSignal - detrendVal ) ./ mean( timeseriesRoiSignal ) * 100;
WAD_vbprint( ['ROI fluctuation: ' num2str(ROI_fluctuation) ' %'] );
WAD_resultsAppendFloat( 1, ROI_fluctuation, 'fluctuation', '%', 'ROI' );


%% create ROI-signal detrended images
imgs_ROI_detrended = zeros( nVolumes, infoFirst.Height, infoFirst.Width );
for i_ix = 1:infoFirst.Width
    for i_iy = 1:infoFirst.Height
        % time series of pixel signal
        imgs_ROI_detrended( :, i_iy, i_ix ) = imgs( :, i_iy, i_ix ) - detrendVal;
    end
end


%% create pixel-wise detrended images
imgs_pix_detrended = zeros( nVolumes, infoFirst.Height, infoFirst.Width );
WAD_vbprint( 'Start pixel-wise detrending...' );
time_s = (0:nVolumes-1)' .* infoFirst.RepetitionTime ./ 1000;
for i_ix = 1:infoFirst.Width
    for i_iy = 1:infoFirst.Height
        % time series of pixel signal
        timeseriesPixelSignal = imgs( :, i_iy, i_ix );
        % mean signal
        meanPixelSignal = mean( timeseriesPixelSignal );
        % detrending with polynomal fit
        [detrendCoeff, ~, muScale] = polyfit( time_s, timeseriesPixelSignal - meanPixelSignal, detrendOrder);
        imgs_pix_detrended( :, i_iy, i_ix ) = timeseriesPixelSignal - polyval( detrendCoeff, time_s, [], muScale );
    end
end


% mean is simply the mean of all images
meanimg = squeeze( mean( imgs ) );

% temporal flucturation noise: sd of residuals after detrending
stdimg = squeeze( std( imgs_pix_detrended ) );

% following fBIRN definition: signal fluctuation to noise ratio (sfnr)
sfnrimg = meanimg ./ stdimg;

% if the images in the timeseries exhibit no drift in amplitude or geometry,
% the noiseAvg image will display no structure from the phantom, and the 
% variance in this image will be a measure of the intrinsic noise.
meanOddimg = mean( imgs_pix_detrended(1:2:end, :, :) );
meanEvenimg = mean( imgs_pix_detrended(2:2:end, :, :) );
noiseAvgimg = squeeze( meanOddimg - meanEvenimg );


%% ROI detrended stats
hFigStats = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Summary Images');
subplot(2,2,1)
colormap( gray(256) );
imagesc( meanimg )
hold on
% show largest ROI as overlay
rectangle( 'Position', [i_iRoiY(1), i_iRoiX(1), roisize, roisize] );
hold off
axis image
axis square
axis off
title( 'Mean signal' )

subplot(2,2,2)
imagesc( stdimg )
axis image
axis square
axis off
title( 'Fluctuation noise' )

subplot(2,2,3)
imagesc( noiseAvgimg )
axis image
axis square
axis off
title( 'Static noise' )

subplot(2,2,4)
imagesc( sfnrimg )
axis image
axis square
axis off
title( 'SFNR = mean/FN' )

WAD_resultsAppendFigure( 1, hFigStats, 'WK_summary', 'summary images' );
if quiet, delete( hFigStats ); end  % delete non-visible image


%% ROI statistics
meanroi = mean2( meanimg( i_iRoiY, i_iRoiX ) );
sdnoise = std2( noiseAvgimg( i_iRoiY, i_iRoiX ) );

% Noise image was averaged over nVolumes / 2, reducing the SD with factor 
% sqrt( nVolumes / 2 ), and subtraction increases the SD with a factor
% sqrt( 2 ), gives total factor of 2 / sqrt( nVolumes )
SNR = meanroi / ( sdnoise / 2 * sqrt( nVolumes ) );
WAD_vbprint( ['ROI SNR : ' num2str(SNR)] )
WAD_resultsAppendFloat( 1, SNR, 'SNR (mean/noise)', [], 'ROI' );


% signal - to - fluctuation noise ratio, calculated over ROI
SFNR = mean2( sfnrimg( i_iRoiY, i_iRoiX ) );
WAD_vbprint( ['ROI SFNR : ' num2str(SFNR)] )
WAD_resultsAppendFloat( 1, SFNR, 'SFNR (mean/fluctuation noise)', [], 'ROI' );

% fluctuation noise - to - static noise ratio
%FNNR = SFNR ./ SNR;
%WAD_vbprint( ['ROI FFNR : ' num2str(FNNR)] )
%WAD_resultsAppendFloat( 1, FNNR, 'FFNR (fluctuation noise/noise)', [], 'ROI' );


%% mask statistics
% create mask using Otsu threshold
meanimgGray = mat2gray( meanimg );
thrLevel = graythresh( meanimgGray );
mask = im2bw( meanimgGray, thrLevel );

hFigMask = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Mask image');
colormap( gray(256) );
imagesc( mask )
axis image
axis square
axis off
title( 'Mask' )
WAD_resultsAppendFigure( 2, hFigMask, 'WK_mask', 'mask image' );
if quiet, delete( hFigMask ); end  % delete non-visible image


meanmask = mean2( meanimg(mask) );
sdnoisemask = std2( noiseAvgimg(mask) );

% Noise image was averaged over nVolumes / 2, reducing the SD with factor 
% sqrt( nVolumes / 2 ), and subtraction increases the SD with a factor
% sqrt( 2 ), gives total factor of 2 / sqrt( nVolumes )
SNR = meanmask / ( sdnoisemask / 2 * sqrt( nVolumes ) );
WAD_vbprint( ['mask SNR : ' num2str(SNR)] )
WAD_resultsAppendFloat( 1, SNR, 'SNR (mean/noise)', [], 'mask' );

% signal - to - fluctuation noise ratio, calculated over mask
SFNR = mean2( sfnrimg(mask) );
WAD_vbprint( ['mask SFNR : ' num2str(SFNR)] )
WAD_resultsAppendFloat( 1, SFNR, 'SFNR (mean/fluctuation noise)', [], 'mask' );


WAD_resultsAppendFloat( 2, mean( meanimg(mask) ), 'mean', [], 'mask' );
WAD_resultsAppendFloat( 2, sqrt( mean ( stdimg(mask) .^2 ) ), 'FN', [], 'mask' );

prctileSD = prctile( stdimg(mask), [ 50 75 90 95 ] );
WAD_resultsAppendFloat( 2, prctileSD(1) , 'FN 50% percentile', [], 'mask' );
WAD_resultsAppendFloat( 2, prctileSD(2) , 'FN 75% percentile', [], 'mask' );
WAD_resultsAppendFloat( 2, prctileSD(3) , 'FN 90% percentile', [], 'mask' );
WAD_resultsAppendFloat( 2, prctileSD(4) , 'FN 95% percentile', [], 'mask' );


hFigHist = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Histogram of FN' );
hist( stdimg(mask) );
title( 'Histogram of FN image' );
xlabel( 'fluctuation noise' )
ylabel( 'count' )
%hFigHistPosition = get(hFigHist, 'Position');
%hFigHistPosition = [ hFigHistPosition(1:2) 200 200 ]; % make smaller size image... doesn't work??
%set(hFigHist, 'Position', hFigHistPosition);

WAD_resultsAppendFigure( 2, hFigHist, 'WK_histogram', 'histogram of fluctuation noise' );
if quiet, delete( hFigHist ); end  % delete non-visible image



%% Temporal and spectrum plots
hFigPlots1 = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Temporal plots' );
% mean signal in ROI over time
subplot(2, 1, 1)
plot( time_s, detrendVal, '- g', time_s, timeseriesRoiSignal, '- b' );
title( 'Mean ROI signal' );
xlabel( 'Time [s]' )
ylabel( 'Signal' )

% spectrum of ROI signal
subplot(2, 1, 2)
fSpectrum_Hz = (0:nVolumes-1)' ./ nVolumes ./ (infoFirst.RepetitionTime / 1000);
magnSpectrum = abs( fft( timeseriesRoiSignal - detrendVal ) );
plot( fSpectrum_Hz(1:nVolumes/2), magnSpectrum(1:nVolumes/2) / meanroi * 100, '- b' );
title( 'Spectrum of mean ROI signal' );
xlabel( 'Freq [Hz]' )
ylabel( 'Magnitude [%]' )

WAD_resultsAppendFigure( 1, hFigPlots1, 'WK_temporal', 'Temporal Plots' );
if quiet, delete( hFigPlots1 ); end  % delete non-visible image



%% Weisskoff plot
WK_Roisize = 1:WK_MxRoisize;
WK_F = zeros(1,WK_MxRoisize);
for roisize = WK_Roisize
    % for ROI's smaller than max ROI size: move ROI over 20x20 pixel area
    % and calculate average of 
    %pixToMove = floor( ( WK_MxRoisize - roisize ) /2 );
    pixToMove = 0;
    %disp( ['ROI size = ' num2str(roisize)] );
    count = 0;
    for roicentreX = -pixToMove : pixToMove
        for roicentreY = -pixToMove : pixToMove
            i_iRoiX = floor( (infoFirst.Width  +roicentreX -roisize)/2 )+1 : ceil( (infoFirst.Width  +roicentreX +roisize)/2 ); % index
            i_iRoiY = floor( (infoFirst.Height +roicentreY -roisize)/2 )+1 : ceil( (infoFirst.Height +roicentreY +roisize)/2 ); % index
            %disp( ['  X = ' num2str(i_iRoiX(1)) ':' num2str(i_iRoiX(end)) ' Y = ' num2str(i_iRoiY(1)) ':' num2str(i_iRoiY(end)) ] );
            % time series of mean signal in ROI
            timeseriesRoiSignal = mean( mean( imgs_pix_detrended( :, i_iRoiY, i_iRoiX ), 3), 2);
            WK_F(roisize) = WK_F(roisize) + std(timeseriesRoiSignal) ./ mean( timeseriesRoiSignal );
            count = count + 1;
        end
    end
    %disp( ['  count = ' num2str(count)] );
    WK_F(roisize) = WK_F(roisize) ./ count;
end

decorrelationDistance_pix = WK_F(1) ./ WK_F(WK_MxRoisize);
WAD_vbprint( ['Decorrelation distance: ' num2str(decorrelationDistance_pix) ' pixels'] )
WAD_resultsAppendFloat( 1, decorrelationDistance_pix, 'distance', 'pixels', 'decorrelation' );


%% Fit noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
% TSRNn = n * SNR / { sqrt( 1 + (n*lambda*SNR) ^2 ) }
x0 = [ SNR, 0 ]; % function parameters: SNR and lambda*1E3
lb = [0 0]; % lower bound: log can't handle negative values
ub = [];    % upper bound: none
options = optimset('Display','off');
[ x, resnorm ] = lsqcurvefit( @logTSNR, x0, WK_Roisize, log(WK_F), lb, ub, options );
noisemodelSNR = x(1);
noisemodelLamda = x(2) ./ 1E03;
WAD_vbprint( ['Noise model SNR: ' num2str(noisemodelSNR) ' Lambda: ' num2str(noisemodelLamda) ] )
WAD_resultsAppendFloat( 2, noisemodelSNR, 'SNR', [], 'noise model' );
WAD_resultsAppendFloat( 2, log10(noisemodelLamda), 'log10(lambda)', [], 'noise model' );



% Theoretically 1/SNR should be equal to F(1).
% In case there is no noise correlation, F should decrease with
% sqrt(number_of_pix_in_ROI) and this equals the 1D ROI size.
% Therefore reference line is drawn as 1/SNR for F(1), devided by ROI size
% for ROI size > 1.
hFigPlots2 = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Weisskoff Plot' );
%loglog( WK_Roisize, (1/SNR) ./ double(WK_Roisize) * 100, '- g', WK_Roisize, TSNR(x,WK_Roisize) * 100, '-- g', WK_Roisize, WK_F * 100, '-ob' );
loglog( WK_Roisize, WK_F(1) ./ double(WK_Roisize) * 100, '- g', WK_Roisize, TSNR(x,WK_Roisize) * 100, '-- g', WK_Roisize, WK_F * 100, '-ob' );
title( 'Weisskoff plot' );
xlabel( 'Full ROI size [pix]' )
ylabel( 'Relative SD [%]' )
axis tight
%xlim( [WK_Roisize(1) WK_Roisize(end)] );
ylim( [ 0.01 10 ] );
grid on

WAD_resultsAppendFigure( 1, hFigPlots2, 'WK_weisskoff', 'Weiskoff Plot' );
if quiet, delete( hFigPlots1 ); end  % delete non-visible image


%% close waitbar in interactive mode
if isInteractive, close( h ), end

return



function F = TSNR( x, n )
% Fit noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
% TSRNn = n*SNR/{sqrt(1+(n*lambda*SNR)^2)}
% x(1) --> SNR
% x(2) --> lambda
F = 1 ./ ( n .* x(1) ./ sqrt( 1 + ( n .* (x(2) ./ 1E03) .* x(1) ) .^2 ) );

function F = logTSNR( x, n )
% Fit noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
% TSRNn = n*SNR/{sqrt(1+(n*lambda*SNR)^2)}
% x(1) --> SNR
% x(2) --> lambda
F = log ( TSNR( x, n ) );
