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

function [magnitude, phase] = WAD_MR_B0_readSiemensServiceStimEcho( i_iSeries, sSeries, sParams )
% Display the image of Siemens service sequence with stimulated echo.
% Acquisition must be single slice.
%
% Interface to the generic routine WAD_MR_B0_uniformity()
%
% Algorithm:
% Display the STE image
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_B0_uniformity_SiemensServiceStimEcho
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2009-12-22 / JK
% first version implemented from Eline Verwer's code.
% ------------------------------------------------------------------------
% 2010-04-20 / JK
% V0.94: added support for Philips double-echo GRE
% ------------------------------------------------------------------------
% 20131127 / JK
% V1.1
% - new (v1.1) style action limits
% ------------------------------------------------------------------------
% 20190718 / JK
% V1.2
% - changed test criteria to recognize the Field service sequence on XA11
%   software level (Sola, Vida)
% ------------------------------------------------------------------------


% output arguments
magnitude = [];
phase = [];


% ----------------------
% GLOBALS
% ----------------------
%global WAD

% version info
my.name = 'WAD_MR_B0_readSiemensServiceStimEcho';
my.version = '1.2';
my.date = '20190718';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );



quiet = 1;
% create figure for B0 map on screen
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end



% ----------------------------------------------------
% check image type, get dicom header of first file
% ----------------------------------------------------
fname = sSeries.instance( 1 ).filename;
WAD_vbprint( [my.name ':   Check type of B0 map... reading DICOM header of file ' fname ] );
info = dicominfo( fname );

if isfield( info, 'SequenceVariant' ) ...
    && ( strcmp( info.SequenceVariant, 'SERVICE\SP' ) || strcmp( info.SequenceVariant, 'SP\SK' ) )
    % && isfield( info, 'SequenceName' ) && strcmp( info.SequenceName, '*' )
    % Siemens stimulated echo service sequence
    WAD_vbprint( [my.name ':   Detected Siemens service stimulated echo.'] );
else
    WAD_vbprint( [my.name ':   Could not detect Siemens service stimulated echo.'] );
    return
end

WAD_vbprint( [my.name ':   Setting type of B0 map to Siemens stimulated echo.'] );

% No quantitative analysis implemented yet, just display the image as a final result
steimg = dicomread( info );

hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Siemens STE image' );
colormap(gray);
% display image 
%imshow( steimg, [] );
colormap( gray(256) );
imagesc( steimg );
axis image
axis square
axis off
hold on

% write plot to calculations log
WAD_vbprint( [my.name ':   Write image to calculations log.' ] );



WAD_resultsAppendString( 2, ['Siemens STE fieldmap from series: ' num2str(sSeries.number)], 'B0 uniformiteit' );
WAD_resultsAppendString( 2, ['Echo Time = ' num2str(info.EchoTime) 'ms'], 'B0 uniformiteit' );

% calculate delta-B per line
gamma_streep = 42.576;  % gyromatric frequency in Hz/T
B0_T = info.MagneticFieldStrength;  % in Tesla
TE_s = info.EchoTime / 1000.0; % TE in sec
dB_per_line_ppm = 1 / ( gamma_streep * B0_T * TE_s ); % dB between two lines in ppm
WAD_resultsAppendString( 2, ['Delta B = ' num2str( dB_per_line_ppm ) ' ppm/line' ], 'B0 uniformiteit' );

figuretitlestring = sprintf( 'Siemens STE. deltaB = %1.2f ppm/line', dB_per_line_ppm );
title( figuretitlestring, 'Interpreter', 'none');

WAD_resultsAppendFigure( 1, hFig, 'STE fieldmap', 'Siemens STE Fieldmap' );

if quiet
    % delete non-visible image
    delete( hFig );
end

% Done with Siemens STE.
return
