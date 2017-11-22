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

function WAD_MR_TxAmplFreq( i_iSeries, sSeries, sParams )
% Get the amplitude and frequency from the DICOM header
%
% Input: series with one or more images, only the first image is read.
%        Parameter options:
%        - if the transmitter amplitude is stored as a number, in a private
%          field (GE), provide the field name, and the data type:
%             <params>
%                 <TxAmpl>
%                     <field>Private_0019_1094</field>
%                     <type>int16</type>
%                 </TxAmpl>
%                 <TxFreq>
%                     <field>ImagingFrequency</field>
%                 </TxFreq>
% Optional:       <TxRefFreq>127.000000</TxRefFreq>
%             </params>
% 
%        - if the transmitter amplitude is in a character private field
%          then we also need the pattern to extract the value (Siemens):
%             <params>
%                 <TxAmpl>
%                     <field>Private_0029_1020</field>
%                     <type>char</type>
%                     <pattern>flReferenceAmplitude = </pattern>
%                 </TxAmpl>
%                 <TxFreq>
%                     <field>ImagingFrequency</field>
%                 </TxFreq>
% Optional:       <TxRefFreq>127.000000</TxRefFreq>
%             </params>
%
%        - The <type> may be omitted for standard DICOM fields.
%        - ImagingFrequency is usually a standard DICOM field.
%
% Output: written via WAD_resultsAppend*() interface
%
% ------------------------------------------------------------------------
% WAD MR
% file: WAD_MR_TxAmplFreq
% 
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2008-10-24 / JK
% first version
% ------------------------------------------------------------------------
% JK - 20120807 v1.0: adapted to WAD framework
% ------------------------------------------------------------------------
% JK - 20131127 v1.1
% - adopted v1.1 style action limits
% - changed result Transmitter Frequency to Transmitter Frequency Offset
%   as workaround for limited number of significant digits during import by
%   WAD processor
% - added config parameter TxFreq.refencence to set reference frequency. If
%   not present, ref freq is calculated from field strength (DICOM header
%   field MagneticFieldStrength).
% ------------------------------------------------------------------------
% 20140212 / JK
% V1.1.1
% Private fields are class uint8 and in one column for implicit DICOM, and class char and one row for explicit DICOM
% char(info.Private_2001_1020(:))' converts both to class char and one row.
% ------------------------------------------------------------------------

% version info
my.name = 'WAD_MR_TxAmplFreq';
my.version = '1.1.1';
my.date = '20140212';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


% read dicom header of first image of series
WAD_vbprint( [my.name ': Reading DICOM header: ' sSeries.instance(1).filename ] );
try
    dicomheader = dicominfo( sSeries.instance(1).filename );
catch err
    WAD_ErrorMsg( my.name, ['ERROR reading DICOM info from file "' sSeries.instance(1).filename '")'], err );
    return
end

% WAD1/2 compatibility: WAD2 has TxAmplField and TxAmplType params.
if ~isfield( sParams, 'TxAmpl' ) && isfield( sParams, 'TxAmplField' )
    sParams.TxAmpl = [];
    sParams.TxAmpl.field = sParams.TxAmplField;
    if isfield( sParams, 'TxAmplType' )
        sParams.TxAmpl.type = sParams.TxAmplType;
    end
end

if ~isfield( sParams, 'TxFreq' ) && isfield( sParams, 'TxFreqField' )
    sParams.TxFreq = [];
    sParams.TxFreq.field = sParams.TxFreqField;
    if isfield( sParams, 'TxFreq_f0_MHz' )
        sParams.TxFreq.f0_MHz = str2double(sParams.TxFreq_f0_MHz);
    end
end

% TxAmpl may not be defined for all system types, because it usually
% resides in a private field.
if isfield( sParams, 'TxAmpl' ) && isfield( sParams.TxAmpl, 'field' )
    % WAD1
    WAD_vbprint( [my.name ': WAD1 type param: getting TX amplitude from header'] );
    TxAmpl = getField( dicomheader, sParams.TxAmpl );
    % Write result
    WAD_resultsAppendFloat( 1, TxAmpl, 'Amplitude', [], 'Transmitter' );
else
    WAD_vbprint( [my.name ': TX amplitude not defined for this system'] );
end

% TxFreq should be defined, but check anyway...
if isfield( sParams, 'TxFreq' ) && isfield( sParams.TxFreq, 'field' )
    WAD_vbprint( [my.name ': Getting TX frequency from header'] );
    TxFreq = getField( dicomheader, sParams.TxFreq );
    % Display frequency as offset
    gamma_MHz = 42.5759;
    if isfield( sParams.TxFreq, 'f0_MHz' ) && ~isempty( sParams.TxFreq.f0_MHz )
        WAD_vbprint( [my.name ': Reference frequency TxFreq.f0_MHz defined in config.'] );
        f0_ref = sParams.TxFreq.f0_MHz;
    elseif isfield( dicomheader, 'MagneticFieldStrength' )
        B0_ref = dicomheader.MagneticFieldStrength;
        WAD_vbprint( [my.name ': Magnetic Field Strength defined in DICOM header, use for Tx Reference Frequency.'] );
        f0_ref = B0_ref * gamma_MHz;
    else
        % no reference, just display f0
        f0_ref = 0;
        WAD_vbprint( [my.name ': No Tx Reference Frequency.'] );
    end
    WAD_resultsAppendFloat( 2, f0_ref * 1E6, 'Referentie Freq', 'Hz', 'Transmitter' );
    

    % Write result
    WAD_resultsAppendFloat( 1, (TxFreq - f0_ref) * 1E6, 'Freq Offset', 'Hz', 'Transmitter' );
else
    WAD_vbprint( [my.name ': TX frequency not defined for this system'] );
end


return


% Local function that reads the numerical value from a DICOM field.
% Implemented are
% - typecast (for implicit type DICOM files and private fields)
% - string search (needed for Siemens systems)
function content = getField( dicomheader, fieldinfo )
my.name = 'WAD_MR_TxAmplFreq:getField';
% get requested number from the dicom header
if isfield( fieldinfo, 'type' )
    if strcmp( fieldinfo.type, 'char' )
        % convert this dicom field to the requested type 'char'
        x = cast( dicomheader.(fieldinfo.field)(:), fieldinfo.type )';

        if isfield( fieldinfo, 'pattern' )
            % find the starting pattern
            %numstart = strfind( x, char(fieldinfo.pattern(1)) ) + length( char(fieldinfo.pattern(1)) );
            numstart = strfind( x, fieldinfo.pattern ) + length( fieldinfo.pattern );
            if numstart
                % find the trailing pattern 
                %numend = strfind( x(numstart:end), char(fieldinfo.pattern(2)) );
                numend = strfind( x(numstart:end), char(10) );
                if numend
                    if ( numend < 3 )
                        WAD_vbprint( [my.name ': Error: reading from header (no number between starting and trailing patterns).'] );
                        content = -1;
                    end
                    content = str2num( x(numstart:numstart+numend(1)-2) );
                else
                    WAD_vbprint( [my.name ': Error: reading from header (trailing pattern not found).'] );
                    content = -1;
                end
            else
                WAD_vbprint( [my.name ': Error: reading from header (starting pattern not found).'] );
                content = -1;
            end
        else
            % no pattern to search for, just convert...
            content = str2num( x );
        end % pattern 
    else
        % not char, we need to typecast the field
        content = double( typecast( dicomheader.(fieldinfo.field), fieldinfo.type ) );
    end
else
    % no additional field type specifiers... should be a number known in
    % dicom dictionary
    content = double( dicomheader.(fieldinfo.field) );
end

return
