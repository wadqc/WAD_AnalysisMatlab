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
% 20190906 / Mette Stam
% Ajusted to support tomosynthesis images in BPO format
% ------------------------------------------------------------------------
% 20200617 / Manon Koot
% Ajusted to support tomosynthesis images in BPO format
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


%load image
img = dicomread( dicomheader );
szImg = size( img );

% check if image is conventional or tomosynthesis projection
if size(szImg,2) == 2 % conventional image
    type_img = 'conventional';
elseif size(szImg,2) == 4 % tomosynthesis projection image
    type_img = 'tomo projection';
end

% ----------------------------
% mAs
% ----------------------------
% mAs should be defined, but check anyway...
switch type_img
    case  'conventional'
        if isfield(dicomheader,'ExposureInuAs')==1
            WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'ExposureInuAs' )) / 1000.0, 'Exposure', 'mAs', 'AEC' );
        elseif isfield(dicomheader,'Exposure')==1
            WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'Exposure' )), 'Exposure', 'mAs', 'AEC' );
        else
            WAD_vbprint( [my.name ':   ERROR: neither ExposureInuAs nor Exposure field are defined in DICOM header.'] );
        end
    case 'tomo projection'
        WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'ExposureInmAs' )), 'Exposure', 'mAs', 'AEC' );
end


% ----------------------------
% Exposure Index
% ----------------------------
% check if field is defined in config file ...
if isfield( sParams, 'EI_field' ) && ~isempty( sParams.EI_field )
    switch type_img
        case  'conventional'
            WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, sParams.EI_field )), 'Exposure Index', [], 'AEC' );
        case 'tomo projection'
            WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader.SharedFunctionalGroupsSequence.Item_1.Unknown_0018_9542.Item_1, sParams.EI_field )), 'Exposure Index', [], 'AEC' );
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
switch type_img
    case  'conventional'
        WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'ExposureTime' )), 'Exposure Time', [], 'AEC' );
    case 'tomo projection'
        WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader.SharedFunctionalGroupsSequence.Item_1.Unknown_0018_9542.Item_1, 'ExposureTimeInms' )), 'Exposure Time', [], 'AEC' );
end


% ----------------------------
% organ dose
% ----------------------------
% For tomosynthesis images there is an organ dose defined per projection
% and for the entire dataset. The numbers do not match completely so 
% suspected is that the organ dose per frame is the intended dose and the 
% total organ dose (in dicomheader.OrganDose) is a measured dose. Needed is
% the collective total of the organ dose.
WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'OrganDose' )), 'Organ Dose', [], 'AEC' );


% ----------------------------
% entrance dose
% ----------------------------
% For tomosynthesis images there is an entrance dose defined per projection
% and for the entire dataset. These numbers match. Needed is the collective
% total of the entrance dose.
WAD_resultsAppendFloat( 1, double( getFieldFromDicomHdr( dicomheader, 'EntranceDoseInmGy' )), 'EntranceDose', 'mGy', 'AEC' );


% ----------------------------
% kVp
% ----------------------------
WAD_resultsAppendFloat( 1, double(getFieldFromDicomHdr( dicomheader, 'KVP' )), 'kVp', 'kV', 'AEC' );


% ----------------------------
% anode target material
% ----------------------------
WAD_resultsAppendString( 1, getFieldFromDicomHdr( dicomheader, 'AnodeTargetMaterial' ), 'AEC Anode Target Material' );


% ----------------------------
% filter material
% ----------------------------
switch type_img
    case  'conventional'
        WAD_resultsAppendString( 1, getFieldFromDicomHdr( dicomheader, 'FilterMaterial' ), 'AEC Filter Material' );
    case 'tomo projection'
        WAD_resultsAppendString( 1, getFieldFromDicomHdr( dicomheader.SharedFunctionalGroupsSequence.Item_1.Unknown_0018_9556.Item_1, 'FilterMaterial' ), 'AEC Filter Material' );
end


% ----------------------------
% ExposureControlModeDescription
% gives position of AEC sensor
% ----------------------------
WAD_resultsAppendString( 1, getFieldFromDicomHdr( dicomheader, 'ExposureControlModeDescription' ), 'AEC Sensor' );




function [value] = getFieldFromDicomHdr( hdr, fieldname )
% local function returns value of dicom field.
my.name = 'WAD_MG_AEC:getFieldFromDicomHdr';
value  = 0;

% check existence of field in header, and get value
if isfield( hdr, fieldname )
    WAD_vbprint( [my.name ':   Getting "' fieldname '" from header...'], 2 );
    value = hdr.(fieldname);
else
    WAD_vbprint( [my.name ':   Field "' fieldname '" not defined in DICOM header.'] ); %this error might be put at a different position because it is confusing when a dicom tag can be at different positions
end
