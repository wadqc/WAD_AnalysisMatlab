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

function WAD_MG_AEC( i_iSeries, sSeries, sParams )
% Get the AEC related parameters from the DICOM header.
% mAs, exposure index, ExposureTime, kVp, filtration,
% ExposureControlModeDescription (=position of the AEC field)
%
% ------------------------------------------------------------------------
% WAD MG
% file: WAD_MG_AEC
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
my.name = 'WAD_MG_AEC';
my.version = '1.1';
my.date = '20131127';
WAD_vbprint( ['Module ' my.name ' Version ' my.version ' (' my.date ')'] );


isInteractive = false;

% read dicom header of first image of currently selected series
fname = sSeries.instance(1).filename;

WAD_vbprint( [my.name ':   reading DICOM image: ' fname ] );

try
    dicomheader = dicominfo( fname );
catch err
    WAD_ErrorMsg( [my.name, 'ERROR reading DICOM file "' fname '"', err] );
    return
end

% ----------------------------
% mAs
% ----------------------------
% mAs should be defined, but check anyway...
[value, status] = getFieldFromDicomHdr( dicomheader, 'ExposureInuAs' );
if status
    WAD_resultsAppendFloat( 1, double(value) / 1000.0, 'Exposure', 'mAs', 'AEC' );
else
    [value, status] = getFieldFromDicomHdr( dicomheader, 'Exposure' );
    if status
        WAD_resultsAppendFloat( 1, double(value), 'Exposure', 'mAs', 'AEC' );
    else
        WAD_vbprint( [my.name ':   ERROR: neither ExposureInuAs nor Exposure field are defined in DICOM header.'] );
    end
end


% ----------------------------
% Exposure Index
% ----------------------------
% check if field is defined in config file ...
if isfield( sParams, 'EI_field' ) && ~isempty( sParams.EI_field )
    [value, status] = getFieldFromDicomHdr( dicomheader, sParams.EI_field );
    if status
        WAD_resultsAppendFloat( 1, double(value), 'Exposure Index', [], 'AEC' );
    end
else
    WAD_vbprint( [my.name ':   Error: no parameter for EI_field containing the DICOM field name for exposure index.'] );
    myErrordlg( isInteractive, ...
        {'The config has no parameter EI_field defined containing the DICOM field name for exposure index.','Please check the SQVID.config file.'}, ...
        'Error getting Exposure Index', 'on' );
end


% ----------------------------
% exposure time
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'ExposureTime' );
if status
    WAD_resultsAppendFloat( 1, double(value), 'Exposure Time', [], 'AEC' );
end


% ----------------------------
% organ dose
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'OrganDose' );
if status
    WAD_resultsAppendFloat( 1, double(value), 'Organ Dose', [], 'AEC' );
end


% ----------------------------
% entrance dose
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'EntranceDoseInmGy' );
if status
    WAD_resultsAppendFloat( 1, double(value), 'EntranceDose', 'mGy', 'AEC' );
end


% ----------------------------
% kVp
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'KVP' );
if status
    WAD_resultsAppendFloat( 1, double(value), 'kVp', [], [] );
end


% ----------------------------
% anode target material
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'AnodeTargetMaterial' );
if status
    WAD_resultsAppendString( 1, value, 'AEC Anode Target Material' );
end


% ----------------------------
% filter material
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'FilterMaterial' );
if status
    WAD_resultsAppendString( 1, value, 'AEC Filter Material' );
end


% ----------------------------
% ExposureControlModeDescription
% gives position of AEC sensor
% ----------------------------
[value, status] = getFieldFromDicomHdr( dicomheader, 'ExposureControlModeDescription' );
if status
    WAD_resultsAppendString( 1, value, 'AEC Sensor' );
end



function [value, status] = getFieldFromDicomHdr( hdr, fieldname )
% local function returns value of dicom field, status true when valid.
my.name = 'WAD_MG_AEC:getFieldFromDicomHdr';
status = false;
value  = 0;

% check existence of field in header, and get value
if isfield( hdr, fieldname )
    WAD_vbprint( [my.name ':   Getting "' fieldname '" from header...'], 2 );
    value = hdr.(fieldname);
    status = true;
else
    WAD_vbprint( [my.name ':   Field "' fieldname '" not defined in DICOM header.'] );
end
