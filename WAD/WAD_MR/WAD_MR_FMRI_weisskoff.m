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


% produce a figure on the screen or be quiet...
%quiet = true;
isInteractive = true;


% version info
my.name = 'WAD_MR_FMRI_weisskoff';
my.version = '0.1';
my.date = '20121205';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


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
nImages = length( instanceNumber )

% sort instances to instance number
[ sorted_nums, instanceNumSortedIndex ] = sort( instanceNumber );

% slice
iSlice = 19;
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
    simuLambda = 0; %0.002;
    imgs = simuSignal ./ simuSNR * randn(size(imgs)) + simuSignal;
    for v=1:nVolumes
        imgs(v,:,:) = imgs(v,:,:) + simuLambda * simuSignal * randn(1,1);
    end
else
    % read DICOM images
    % display waitbar in interactive mode
    if isInteractive, h = waitbar( 0, 'Reading images...' ); end

    % loop over images
    i_icVol = 1;
    % Siemens / GE give all slices of a volume
    %disp('Siemens / GE slice/time order!!!')
    %for i_icNum = iSlice + nVolumesToSkip*nSlices : nSlices : nImages
    % Philips give all time points of a slice
    disp('Philips slice/time order!!!')
    for i_icNum = 1 + iSlice*nVolumesTotal + nVolumesToSkip : (iSlice+1)*nVolumesTotal
        %disp( i_icNum )
        % read image   
        img = dicomread( sSeries.instance( instanceNumSortedIndex(i_icNum) ).filename );
        imgs( i_icVol, : , : ) = img;
        i_icVol = i_icVol + 1;
        % update waitbar
        % Siemens / GE
        %if isInteractive, waitbar( i_icNum / nImages, h ); end
        % Philips
        if isInteractive, waitbar( i_icNum / nVolumes, h ); end
    end

    %imshow(reshape(imgs(1,:,:),infoFirst.Height,infoFirst.Width),[])

    % close waitbar in interactive mode
    if isInteractive, close( h ), end
end

% display waitbar in interactive mode
if isInteractive, h = waitbar( 0, 'Calculating...' ); end

% TODO: eerst pixel-wise detrending???
WAD_vbprint( 'Start pixel-wise detrending...' );
time_s = (0:nVolumes-1)' .* infoFirst.RepetitionTime ./ 1000;
for i_ix = 1:infoFirst.Width
    for i_iy = 1:infoFirst.Height
        % time series of pixel signal
        timeseriesPixelSignal = imgs( :, i_iy, i_ix );
        % mean signal
        meanPixelSignal = mean( timeseriesPixelSignal );
        % detrending with 2nd order polynomal
        detrendCoeff = polyfit( time_s, timeseriesPixelSignal - meanPixelSignal, 2);
        imgs( :, i_iy, i_ix ) = timeseriesPixelSignal - polyval( detrendCoeff, time_s );
    end
end

meanimg = mean( imgs );
stdimg = std(imgs);

meanOddimg = mean( imgs(1:2:end, :, :) );
meanEvenimg = mean( imgs(2:2:end, :, :) );
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

% square ROI
roisize = 20; % size
i_iRoiX = floor( (infoFirst.Width -roisize)/2 )+1 : ceil( (infoFirst.Width +roisize)/2 ); % index
i_iRoiY = floor( (infoFirst.Height-roisize)/2 )+1 : ceil( (infoFirst.Height+roisize)/2 ); % index
%i_iRoiY = 29:48;

% TODO: automatic centre pos of ROI, and ROI display on images for visual
% check.

% ROI statistics
meanroi = mean2( meanimg( 1, i_iRoiY, i_iRoiX ) );
sdnoise = std2( noiseAvgimg( 1, i_iRoiY, i_iRoiX ) );

% Noise image was averaged over nVolumes / 2, reducing the SD with factor 
% sqrt( nVolumes / 2 ), and subtraction increases the SD with a factor
% sqrt( 2 ), gives total factor of 2 / sqrt( nVolumes )
SNR = meanroi / ( sdnoise / 2 * sqrt( nVolumes ) )
% signal fluctuation - to - noise ratio
SFNR = mean2( sfnrimg( 1, i_iRoiY, i_iRoiX ) )


% time series of mean signal in ROI
timeseriesRoiSignal = mean( mean( imgs( :, i_iRoiY, i_iRoiX ), 3), 2);
% detrending with 2nd order polynomal
time_s = (0:nVolumes-1)' .* infoFirst.RepetitionTime ./ 1000;
detrendCoeff = polyfit( time_s, timeseriesRoiSignal , 2);
detrendVal = polyval( detrendCoeff, time_s );

% trend is difference in signal between start and end, per unit time
trend_ps = ( detrendVal(end) - detrendVal(1) ) ./ ( time_s(end) - time_s(1) )

% SFNR after detrending
%stdimg = std(imgs - detrendVal); --> dit werkt niet, matrix sizes komen
%niet overeen. TODO: detrending per pixel????
%sfnrimg = meanimg ./ stdimg;
%SFNR = mean2( sfnrimg( 1, i_iRoiY, i_iRoiX ) )


hFigPlots = figure();
% mean signal in ROI over time
subplot(3, 1, 1)
plot( time_s, detrendVal, '- g', time_s, timeseriesRoiSignal, '- b' );
title( 'Mean ROI signal' );
xlabel( 'Time [s]' )
ylabel( 'Signal' )

% spectrum of ROI signal
subplot(3, 1, 2)
fSpectrum_Hz = (0:nVolumes-1)' ./ nVolumes ./ (infoFirst.RepetitionTime / 1000);
magnSpectrum = abs( fft( timeseriesRoiSignal - detrendVal ) );
plot( fSpectrum_Hz(1:nVolumes/2), magnSpectrum(1:nVolumes/2), '- b' );
title( 'Spectrum of mean ROI signal' );
xlabel( 'Freq [Hz]' )
ylabel( 'Magnitude' )

% Weisskoff plot
WK_MxRoisize = 20;
WK_Roisize = 1:WK_MxRoisize;
WK_F = zeros(1,WK_MxRoisize);
for roisize = WK_Roisize
    % for ROI's smaller than max ROI size: move ROI over 20x20 pixel area
    % and calculate average of 
    pixToMove = 0; % floor( ( WK_MxRoisize - roisize ) /2 );
    %WK_F(roisize) = 0;
    disp( ['ROI size = ' num2str(roisize)] );
    count = 0;
    for roicentreX = -pixToMove : pixToMove
        for roicentreY = -pixToMove : pixToMove
            i_iRoiX = floor( (infoFirst.Width  +roicentreX -roisize)/2 )+1 : ceil( (infoFirst.Width  +roicentreX +roisize)/2 ); % index
            i_iRoiY = floor( (infoFirst.Height +roicentreY -roisize)/2 )+1 : ceil( (infoFirst.Height +roicentreY +roisize)/2 ); % index
            disp( ['  X = ' num2str(i_iRoiX(1)) ':' num2str(i_iRoiX(end)) ' Y = ' num2str(i_iRoiY(1)) ':' num2str(i_iRoiY(end)) ] );
            % time series of mean signal in ROI
            timeseriesRoiSignal = mean( mean( imgs( :, i_iRoiY, i_iRoiX ), 3), 2);
            %detrendCoeff = polyfit( time_s, timeseriesRoiSignal , 2);
            %detrendVal = polyval( detrendCoeff, time_s );
            %display( ['sd = ' num2str(std(timeseriesRoiSignal-detrendVal)) '  mean = ' num2str( mean( timeseriesRoiSignal ) ) ] );
            %WK_F(roisize) = WK_F(roisize) + std(timeseriesRoiSignal-detrendVal) ./ mean( timeseriesRoiSignal );
            WK_F(roisize) = WK_F(roisize) + std(timeseriesRoiSignal) ./ mean( timeseriesRoiSignal );
            count = count + 1;
        end
    end
    disp( ['  count = ' num2str(count)] );
    WK_F(roisize) = WK_F(roisize) ./ count;
end

% Fit noise model from Bodurka et al, ISMRM 14 (2006), p. 1094
% TSRNn = n * SNR / { sqrt( 1 + (n*lambda*SNR) ^2 ) }
x0 = [ SNR, 0 ]; % function parameters: SNR and lambda*1E3
lb = [0 0]; % lower bound: log can't handle negative values
ub = [];    % upper bound: none
[ x, resnorm ] = lsqcurvefit( @logTSNR, x0, WK_Roisize, log(WK_F), lb, ub );
noisemodelSNR = x(1)
noisemodelLamda = x(2) ./ 1E03

subplot(3, 1, 3)
% Theoretically 1/SNR should be equal to F(1).
% In case there is no noise correlation, F should decrease with
% sqrt(number_of_pix_in_ROI) and this equals the 1D ROI size.
% Therefore reference line is drawn as 1/SNR for F(1), devided by ROI size
% for ROI size > 1.
loglog( WK_Roisize, (1/SNR) ./ double(WK_Roisize), '- g', WK_Roisize, TSNR(x,WK_Roisize), '-- g', WK_Roisize, WK_F, '-ob' );
title( 'Weisskoff plot' );
xlabel( 'Full ROI size [pix]' )
ylabel( 'Rel. STD' )
axis tight
%xlim( [WK_Roisize(1) WK_Roisize(end)] );

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
