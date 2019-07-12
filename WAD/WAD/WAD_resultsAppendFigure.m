% ------------------------------------------------------------------------
% This WAD folder provides a "library" of helper functions written for IQC.
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

function WAD_resultsAppendFigure( level, handle, tag, description )
% Append jpeg figure to WAD results object
%
% ------------------------------------------------------------------------
% WAD
% file: WAD_resultsAppendFigure
% 
% input:   - handle: Matlab figure handle
%          - tag: string to tag the file name
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2012-05-23 / JK
% first version
% ------------------------------------------------------------------------

global WAD

WAD_vbprint( 'Module WAD_resultsAppendFigure()', 2 );

% save figure
fnameimg = sprintf( '%s_%s.jpg', datestr( now, 'yyyymmdd_HHMMSS' ), tag );
saveas( handle, fullfile( WAD.in.analysemodule_outputdir, fnameimg ) );

% add to results
WAD_resultsAppendObject( level, fnameimg, description );
