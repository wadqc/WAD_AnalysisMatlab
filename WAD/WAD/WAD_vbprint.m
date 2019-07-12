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

function WAD_vbprint( arg, level )
% vbprint is used for tracing / debugging / logging
% where the text output goes to, is defined by WAD.cfg.logverbose

global WAD


if ( nargin ~= 2 )
    level = 1;
end

if ( level <= WAD.cfg.logverbose.level )
    if ( bitand( WAD.cfg.logverbose.mode, 1 ) && ( WAD.cfg.logverbose.fid ~= -1 ) )
        fprintf( WAD.cfg.logverbose.fid, '%s\n', arg );
    end

    if ( bitand( WAD.cfg.logverbose.mode, 2 ) )
        % print to screen
        fprintf( '%s\n', arg );
    end  
end

return
