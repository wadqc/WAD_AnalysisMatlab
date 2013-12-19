%*******************************************************************************
% Virginia Tech - Wake Forest University ACR AutoQA Software
% 
% Copyright (c) 2005 Atiba Fitzpatrick and Chris Wyatt
% Copyright (c) modifications 2008-2013 Joost Kuijer
%
% Permission is hereby granted, free of charge, to any person
% obtaining a copy of this software and associated documentation
% files (the "Software"), to deal in the Software without
% restriction, including without limitation the rights to use,
% copy, modify, merge, publish, distribute, sublicense, and/or 
% sell copies of the Software, and to permit persons to whom the 
% Software is furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be
% included in all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
% OTHER DEALINGS IN THE SOFTWARE.
%******************************************************************************

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


function [SNR, ghostRow_percent, ghostCol_percent, PIU, figureHandle] = WAD_MR_privateSNR_ghost( image, centrePos_pix, sParams, quiet )
% Calculate SNR and ghosting and Percent Image Uniformity on image.
% Input
% - image        : structure with field .fname containing the image filename.
% - centrePox_pix: coordinates of centre of image (from SQ_MR_sizePos_pix).
% - sParams.ROIshift: shift [mm] from centre to sideways ROIs in background.
% - sParams.ROIradius: radius [mm] of large (phantom) ROI.
% - sParams.backgroundROIsize: size of background ROI's, rectangular ROI's for ghosting have length multiplied by 4.
%
% Output
% - SNR, ghost*, PIU: results
% - figureHandle: optional, returns plot with ROI's used for evalutation
%   overlaid on the image
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Modified by: Joost Kuijer / Frank de Weerd / VUmc
% 29/08/2008
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% JK - 19/12/2013
% Bugfix: execution sometimes hangs in ROImask() in compiled version.
% Replaced immultiply() and imcomplement() by regular mathematic
% expressions.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% only calculate what's requested
calcGhosting   = false;
calcUniformity = false;
if nargout > 1, calcGhosting   = true; end
if nargout > 3, calcUniformity = true; end

% Get the initial image
fname = image.filename;
info = dicominfo( fname );
slice = double( dicomread( fname ) );

% definitions of ROI sizes/locations
% ... and convert mm to pixels
radius  = sParams.ROIradius          / info.PixelSpacing(1);    % radius of large ROI
Blength = sParams.backgroundROIsize  / info.PixelSpacing(1);    % length of background ROIs
%shift   = 108 / info.PixelSpacing(1);    % shift from centre of phantom to background ROIs
shift   = sParams.backgroundROIshift / info.PixelSpacing(1);    % shift from centre of phantom to background ROIs

cent = centrePos_pix; % centre of phantom
shiftx = [0, shift];  % shift from centre for ghosting and background ROIs
shifty = [shift, 0];

% 4 background ROI's for ghosting, on all sides near the phantom
centtop   = centrePos_pix - shiftx;    % center of top ROI
centbtm   = centrePos_pix + shiftx;    % center of bottom ROI
centright = centrePos_pix - shifty;    % center of right ROI
centleft  = centrePos_pix + shifty;    % center of left ROI

% 4 background ROI's in the corners of the image for noise estimation
centbckgbl  = centrePos_pix + shiftx + shifty;  % center of background ROI
centbckgtl  = centrePos_pix + shiftx - shifty;  % center of background ROI
centbckgbr  = centrePos_pix - shiftx + shifty;  % center of background ROI
centbckgtr  = centrePos_pix - shiftx - shifty;  % center of background ROI

% Determine mean value in centre and ghosting ROIs
[B,M]           = ROImask(radius,radius,cent,slice,0);
if calcGhosting
    [Btop,Mtop]     = ROImaskrec(Blength*4,Blength  ,centtop,slice,0);
    [Bbtm,Mbtm]     = ROImaskrec(Blength*4,Blength  ,centbtm,slice,0);
    [Bright,Mright] = ROImaskrec(Blength  ,Blength*4,centright,slice,0);
    [Bleft,Mleft]   = ROImaskrec(Blength  ,Blength*4,centleft,slice,0);
end

% background (noise) ROI's
[Bbckgbl,Mbckgbl] = ROImaskrec(Blength,Blength,centbckgbl,slice,0);
[Bbckgtl,Mbckgtl] = ROImaskrec(Blength,Blength,centbckgtl,slice,0);
[Bbckgbr,Mbckgbr] = ROImaskrec(Blength,Blength,centbckgbr,slice,0);
[Bbckgtr,Mbckgtr] = ROImaskrec(Blength,Blength,centbckgtr,slice,0);
% because background ROI's are not overlapping, we just add them up
Bbckg = Bbckgbl + Bbckgtl + Bbckgbr + Bbckgtr;
Mbckg = Mbckgbl + Mbckgtl + Mbckgbr + Mbckgtr;

meanLarge = sum(B(:))/sum(M(:));
meanbckg  = sum(Bbckg(:))/sum(Mbckg(:));
if calcGhosting
    meantop   = sum(Btop(:))/sum(Mtop(:));
    meanbtm   = sum(Bbtm(:))/sum(Mbtm(:));
    meanright = sum(Bright(:))/sum(Mright(:));
    meanleft  = sum(Bleft(:))/sum(Mleft(:));

    % ACR definition of Percent Signal Ghosting
    ghostRow_percent = 100 * ( max( meanleft, meanright ) - meanbckg ) / (2.0 * meanLarge);
    ghostCol_percent = 100 * ( max( meantop , meanbtm   ) - meanbckg ) / (2.0 * meanLarge);
end

% standard deviation of background ROI
[n,m]=size(slice);
Sbckg = zeros(1,n*m); % preallocate mem
k = 0;
for i=1:n,
    for j=1:m,
        if (Mbckg(i,j) > 0)
            k = k+1;
            Sbckg(k) = Bbckg(i,j);
        end
    end
end
% resize mem
Sbckg = Sbckg(1:k);
% calc SD
STDbckg = std( Sbckg );

% SNR --> not true SNR because this need correction for magnitude recon
SNR = meanLarge / STDbckg;


% -----------------------------------------------------------------------
% Homogeneity
% -----------------------------------------------------------------------
% begin FdW
if calcUniformity
    [numr,numc]=size(slice);
    centra_plot = zeros(numr,numc);

    run=0;
    for r=0:0.1:0.9,
       r_dummy = r;
       if(r==0)              % avoid dividing by zero
           r_dummy=0.001;    % any number smaller than 1/360 will do
       end    
       for theta= 0 : 5/r_dummy : 360, % counterclockwise vanaf 6h
          run=run+1;
          shift_dummy_x = [0, r*radius*cos(2*pi*theta/360)];
          shift_dummy_y = [r*radius*sin(2*pi*theta/360), 0];
          cent_dummy = centrePos_pix + shift_dummy_x + shift_dummy_y;  
          centra_plot(round(cent_dummy(2)),round(cent_dummy(1))) = 1;      % let op de volgorde!!
          [Bdummy,Mdummy] = ROImask(radius/10,radius/10,cent_dummy,slice,0);
          mean_dummy = sum(Bdummy(:))/sum(Mdummy(:));

          %all_means(run) = mean_dummy;       % for making a histogram of means

          if(run==1)
               largest = mean_dummy;
               smallest = mean_dummy;
               cent_largest = cent_dummy;
               cent_smallest = cent_dummy;
          else
              if (mean_dummy > largest)
                  largest = mean_dummy;
                  cent_largest = cent_dummy;
              elseif (mean_dummy < smallest)
                  smallest = mean_dummy;
                  cent_smallest = cent_dummy;
              end    
          end
      end
    end
    

    %largest
    %smallest
    %cent_largest
    %cent_smallest
    PIU = 100 .* (1 - (largest - smallest) / (largest + smallest));

    % figure; hist(all_means);

    [Blargest,Mlargest]   = ROImask( radius ./ 10.0, radius ./ 10.0, cent_largest,  slice, 0);
    [Bsmallest,Msmallest] = ROImask( radius ./ 10.0, radius ./ 10.0, cent_smallest, slice, 0);
end
% end part 1 FdW, also changes in the figure below 

% create figure
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end
% reasons for plotting a figure...
makefig = (nargout > 4) || ~quiet;

if makefig
    % create figure
    hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'SNR / Ghosting' );
    colormap(gray);
    theImage = slice/10 + B + Bbckg + 0.001;
    if calcGhosting
        theImage = theImage + Btop + Bbtm + Bright + Bleft;
    end
    if calcUniformity
        % FdW: Blargest and Bsmallest and centra_plot added
        theImage = theImage - Blargest - Bsmallest + 10000*centra_plot;
    end
    imagesc( log( theImage ) );
    axis image
    axis square
    axis off
    title('ROIs for SNR/Ghosting', 'Interpreter', 'none');
end


% save figure
%[pathstr, name, ext] = fileparts(fname);
%saveas( gcf, fullfile(pathstr,'acrNoise.jpg'));

% return figure handle if it was requested
if nargout > 4
    figureHandle = hFig;
end

end



%%%%%%%%%%%%%%%%%%%%   SUB-FUNCTION    %%%%%%%%%%%%%%%%%%%%%%%%%%   

function [B,M] = ROImask(a,b,cent,I,valfill)
% Creates an elliptical mask defined by paramaters a, b and cent. Multiples
% this mask to I and fills all pixels outside ellipse with valfill
centx = cent(1);
centy = cent(2);
[numr,numc] = size(I);
[x,y] = meshgrid( 1:numc, 1:numr );
M = double( ((x-centx).^2) ./ a.^2 + ((y-centy).^2) ./ b.^2 <= 1 );
B = M .* I + ( 1.0 - M ) .* valfill;
end

function [B,M] = ROImaskrec(a,b,cent,I,valfill)
% Creates an rectangular mask defined by paramaters a, b and cent. Multiples
% this mask to I and fills all pixels outside rectangle with valfill
centx = cent(1);
centy = cent(2);
[numr,numc] = size(I);
[x,y] = meshgrid( 1:numc, 1:numr );
M = double( and( abs(x-centx) < a, abs(y-centy) < b ) );
B = M .* I + ( 1.0 - M ) .* valfill;
end
