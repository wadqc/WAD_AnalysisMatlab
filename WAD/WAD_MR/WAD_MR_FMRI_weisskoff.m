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

function WAD_MR_FMRI_weisskoff( i_iSeries, sSeries, sParams, sLimits )
% FMRI-specific QC procedures on EPI images
% ------------------------------------------------------------------------
% WAd MR
% file: WAD_MR_FMRI_weisskoff
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2010-11-10 / JK
% first version
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-12-05 / JK
% adapted to WAD
% ------------------------------------------------------------------------
% Implementation of QC tests for fMRI purposes:
% Relevant references:
% - Lee Friedman and Gary H. Glover. Report on a Multicenter fMRI Quality
%   Assurance Protocol. J Magn Res Imag 23:827–839 (2006)
% - Weisskoff RM. Simple measurement of scanner stability for functional NMR
%   imaging of activation in the brain. Magn Reson Med 1996;36:643-645
% - Bodurka et al, ISMRM 14 (2006), p. 1094


% produce a figure on the screen or be quiet...
%quiet = true;
isInteractive = true;


% version info
my.name = 'WAD_MR_FMRI_weisskoff';
my.version = '0.1';
my.date = '20121205';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% *** TODO: configurable parameters ***
% *** TODO: get from sParams (from configuration XML file) ***

% slice to analyse
iSlice = 10;

% ROI size for summary statistics (SNR, FSNR etc)
roisize = 20; % size

% max ROI size for Weisskoff plot
WK_MxRoisize = 20;

% detrending: order of polynomal fit
detrendOrder = 5;

% % ---------------------------------------------
% % select the plain water image without features
% % ---------------------------------------------
% % default: use configured slice
% inum = handles.config.MR.img4SNR;
% % may be overruled by series config...
% if isfield( handles.imdb.series(cs), 'img4SNR' ) && ~isempty( handles.imdb.series(cs).img4SNR )
%     inum = handles.imdb.series(cs).img4SNR;
%     % handle specials...
%     if inum == handles.config.MR.combinedImageFirst
%         inum = 1;
%     elseif inum == handles.config.MR.combinedImageLast
%         inum = length( handles.imdb.series(cs).image );
%     end
% end
% % is it just one slice? then we use it...
% if length( handles.imdb.series(cs).image ) == 1
%     inum = 1;
% end
% 

% list of instance numbers
instanceNumber = [sSeries.instance(:).number];
nImages = length( instanceNumber );
WAD_vbprint( ['Number of images: ' num2str(nImages) ] );

% sort instances to instance number
[ sorted_nums, instanceNumSortedIndex ] = sort( instanceNumber );

% initial volumes (measurements, acquisitions, samples, whatever you like to call them) to skip
nVolumesToSkip = 2;
WAD_vbprint( ['Skipping first ' num2str(nVolumesToSkip) ' volumes.'] );

% Probe first image
infoFirst = dicominfo( sSeries.instance( instanceNumSortedIndex(1) ).filename );

nVolumesTotal = infoFirst.NumberOfTemporalPositions;
nVolumes = nVolumesTotal - nVolumesToSkip;

if mod( nImages, nVolumesTotal )
    WAD_vbprint( 'Warning: FMRI number of images not a multiple of number of volumes.' );
    myWarndlg( isInteractive, 'Number of images not a multiple of number of volumes', 'FMRI', 'on' );
end

nSlices = floor( nImages ./ nVolumesTotal );

% Check: non-square images not tested yet...
if infoFirst.Width ~= infoFirst.Height
    WAD_vbprint( 'Error: FMRI number of images not a multiple of number of volumes.' );
    myErrordlg( isInteractive, 'Sorry: non-square image matrix not supported yet.', 'FMRI', 'on' );
    return
end


% allocate space for images
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
    % read DICOM images
    % display waitbar in interactive mode
    if isInteractive, h = waitbar( 0, 'Reading images...' ); end

    %h1 = figure();
    % loop over images
    i_icVol = 1;
    % Siemens / GE give all slices of a volume
    disp('Siemens / GE / Toshiba slice/time order!!!')
    for i_icNum = iSlice + nVolumesToSkip*nSlices : nSlices : nImages
    % Philips give all time points of a slice
    %disp('Philips slice/time order!!!')
    %for i_icNum = 1 + iSlice*nVolumesTotal + nVolumesToSkip : (iSlice+1)*nVolumesTotal
        %disp( i_icNum )
        % read image   
        img = dicomread( sSeries.instance( instanceNumSortedIndex(i_icNum) ).filename );
        %figure(h1);
        %imshow(img,[])
        imgs( i_icVol, : , : ) = img;
        i_icVol = i_icVol + 1;
        % update waitbar
        % Siemens / GE
        if isInteractive, waitbar( i_icNum / nImages, h ); end
        % Philips
        %if isInteractive, waitbar( i_icNum / nVolumes, h ); end
    end
    %imshow(reshape(imgs(1,:,:),infoFirst.Height,infoFirst.Width),[])

    % close waitbar in interactive mode
    if isInteractive, close( h ), end
end

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating...' ); end

disp( ['Fitted polynomal order for detrending: ' num2str(detrendOrder)] )

% square ROI for summary statistics
disp( ['ROI size for summary statistics: ' num2str(roisize) ' pixels'] )
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
disp( ['ROI trend      : ' num2str(ROI_trend_percent) ' %'] );

% fluctuation is SD of residual after detrending
ROI_fluctuation = std( timeseriesRoiSignal - detrendVal ) ./ mean( timeseriesRoiSignal ) * 100;
disp( ['ROI fluctuation: ' num2str(ROI_fluctuation) ' %'] );


% create ROI-signal detrended images
imgs_ROI_detrended = zeros( nVolumes, infoFirst.Height, infoFirst.Width );
for i_ix = 1:infoFirst.Width
    for i_iy = 1:infoFirst.Height
        % time series of pixel signal
        imgs_ROI_detrended( :, i_iy, i_ix ) = imgs( :, i_iy, i_ix ) - detrendVal;
    end
end


% create pixel-wise detrended images
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
meanimg = mean( imgs );

% temporal flucturation noise: sd of residuals after detrending
stdimg = std( imgs_pix_detrended );

% if the images in the timeseries exhibit no drift in amplitude or geometry,
% the noiseAvg image will display no structure from the phantom, and the 
% variance in this image will be a measure of the intrinsic noise.
meanOddimg = mean( imgs_pix_detrended(1:2:end, :, :) );
meanEvenimg = mean( imgs_pix_detrended(2:2:end, :, :) );
noiseAvgimg = meanOddimg - meanEvenimg;

% following fBIRN definition: signal fluctuation to noise ratio (sfnr)
sfnrimg = meanimg ./ stdimg;


hFigStats = figure();
subplot(2,2,1)
imshow( reshape(meanimg(1,:,:),infoFirst.Height,infoFirst.Width), [] )
title( 'Mean signal' )

subplot(2,2,2)
imshow( reshape(stdimg(1,:,:),infoFirst.Height,infoFirst.Width), [] )
title( 'SD signal' )

subplot(2,2,3)
imshow( reshape(noiseAvgimg(1,:,:),infoFirst.Height,infoFirst.Width), [] )
title( 'Mean noise' )

subplot(2,2,4)
imshow( reshape(sfnrimg(1,:,:),infoFirst.Height,infoFirst.Width), [] )
title( 'SFNR = mean/SD' )


% TODO: ROI display on images for visual check.

% ROI statistics
meanroi = mean2( meanimg( 1, i_iRoiY, i_iRoiX ) );
sdnoise = std2( noiseAvgimg( 1, i_iRoiY, i_iRoiX ) );

% Noise image was averaged over nVolumes / 2, reducing the SD with factor 
% sqrt( nVolumes / 2 ), and subtraction increases the SD with a factor
% sqrt( 2 ), gives total factor of 2 / sqrt( nVolumes )
SNR = meanroi / ( sdnoise / 2 * sqrt( nVolumes ) );
disp( ['SNR : ' num2str(SNR)] )
% signal fluctuation - to - noise ratio
% calculated over largest ROI size
SFNR = mean2( sfnrimg( 1, i_iRoiY, i_iRoiX ) );
disp( ['SFNR : ' num2str(SFNR)] )



hFigPlots1 = figure();
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

% Weisskoff plot
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
disp( ['Decorrelation distance: ' num2str(decorrelationDistance_pix) ' pixels'] )

% Fit noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
% TSRNn = n * SNR / { sqrt( 1 + (n*lambda*SNR) ^2 ) }
x0 = [ SNR, 0 ]; % function parameters: SNR and lambda*1E3
lb = [0 0]; % lower bound: log can't handle negative values
ub = [];    % upper bound: none
[ x, resnorm ] = lsqcurvefit( @logTSNR, x0, WK_Roisize, log(WK_F), lb, ub );
noisemodelSNR = x(1);
noisemodelLamda = x(2) ./ 1E03;
disp( ['Noise model SNR: ' num2str(noisemodelSNR) ' Lambda: ' num2str(noisemodelLamda) ] )


% Theoretically 1/SNR should be equal to F(1).
% In case there is no noise correlation, F should decrease with
% sqrt(number_of_pix_in_ROI) and this equals the 1D ROI size.
% Therefore reference line is drawn as 1/SNR for F(1), devided by ROI size
% for ROI size > 1.
hFigPlots2 = figure();
%loglog( WK_Roisize, (1/SNR) ./ double(WK_Roisize) * 100, '- g', WK_Roisize, TSNR(x,WK_Roisize) * 100, '-- g', WK_Roisize, WK_F * 100, '-ob' );
loglog( WK_Roisize, WK_F(1) ./ double(WK_Roisize) * 100, '- g', WK_Roisize, TSNR(x,WK_Roisize) * 100, '-- g', WK_Roisize, WK_F * 100, '-ob' );
title( 'Weisskoff plot' );
xlabel( 'Full ROI size [pix]' )
ylabel( 'Rel. STD [%]' )
axis tight
%xlim( [WK_Roisize(1) WK_Roisize(end)] );
ylim( [ 0.01 10 ] );
grid on

% close waitbar in interactive mode
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
