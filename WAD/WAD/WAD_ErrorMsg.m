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

function WAD_ErrorMsg( name, mymessage, err )
% Write some info about the error to the log file
WAD_vbprint( [name ': --------------------ERROR-------------------------' ] );
WAD_vbprint( [name ': ' mymessage] );
WAD_vbprint( [name ': ' err.message] );
for i=1:length( err.stack )
    WAD_vbprint( [name ': File: ' err.stack(i).file '  Function: ' err.stack(i).name '  Line: ' num2str(err.stack(i).line)] );
end
WAD_vbprint( [name ': --------------------------------------------------' ] );
