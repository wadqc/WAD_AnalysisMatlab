% add m2html dir to matlab path
%addpath D:\SQVID\src_wad\m2html
% run m2html with options for frame, menu, global (allows cross-referencing between modules)
m2html('mfiles',{'WAD' 'WAD_MG' 'WAD_MR' 'WAD_demo' 'xml_io_tools'}, 'htmldir','doc', 'template','frame', 'index','menu', 'graph','off', ', 'global','on');