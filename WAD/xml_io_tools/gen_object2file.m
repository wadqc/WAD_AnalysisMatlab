function gen_object2file( fid, obj_struct, indent )
%
% gen_object2file - general function to display an object's content
%
% format:   gen_object2file( fid, obj_struct, indent )
%
% input:    fid         - file ID
%           obj_struct  - a copy of the object stored inside a structure
%           indent      - amount of "indent" when printing to the screen
%
% output:   to file
%
% example:  gen_object2file( fid, struct( my_object_handle) );
%           gen_object2file( fid, ny_structure );
%
% Correction History:
%  2006-11-01 - Jarek Tuszynski - added support for struct arrays
%  2012-09-06 - Joost Kuijer - write to file

%% handle insufficient input
if ( nargin < 2 )
  help gen_object2file;
  return;
elseif (nargin == 2)
  indent = 1;
end

%% check input for errors
% if ~isstruct( obj_struct )
%     fprintf( '\n\n\tMake sure that ''obj_struct'' is a struct type\n' );
%     return
% end

% if (iscell( obj_struct ))
%   for i =1:length(obj_struct)
%     gen_object2file( fid, obj_struct{i},indent + 2 );
%   end
%   return
% end
if ~isstruct( obj_struct )
  % JK skipping this...
  %space = sprintf( sprintf( '%%%ds',indent ),' ' );
  %fprintf( '   %s', space);
  %disp(obj_struct);
  return
end

% find the longest name
field_list      = fieldnames( obj_struct );
max_strlen      = 0;
for idx = 1:length( field_list )
  max_strlen  = max( max_strlen,length(field_list{idx}) );
end

%% setup the display format (spacing)
space       = sprintf( sprintf( '%%%ds',indent ),' ' );
name_format = sprintf( '   %s%%%ds: ', space, max_strlen );
name_format2= sprintf( '     %s%%%ds', space, max_strlen );
max_displen = 140 - max_strlen - indent; % JK - increased from 110 to 140

%% display each field, if it is not too long
for iItem = 1:length( obj_struct ) % loop added  by JT
  for idx = 1:length( field_list )
    
    % prepare field name to be displayed
    name = sprintf( name_format,field_list{idx} );
    %temp = getfield( obj_struct,field_list{idx} ); % original by OG
    temp = obj_struct(iItem).(field_list{idx});    % modification by JT
    
    % proceed according the variable's type
    switch (1)
      case islogical( temp ), % case added by JT
        if isscalar(temp)
          if (temp)
            fprintf( fid, '%strue\n',name );
          else
            fprintf( fid, '%sfalse\n',name );
          end
        else
          fprintf( fid, '%s[%dx%d logical]\n',name,size(temp,1),size(temp,2) );
        end
      case ischar( temp ),
        if (length(temp)<max_displen )
          fprintf( fid, '%s''%s''\n',name,temp' );
        else
          fprintf( fid, '%s[%dx%d char]\n',name,size(temp,1),size(temp,2) );
        end
      case isnumeric( temp ),
        if (size( temp,1 )==1 )
          temp_b = num2str( temp );
          if (length(temp_b)<max_displen )
            fprintf( fid, '%s[%s]\n',name,temp_b );
          else
            fprintf( fid, '%s[%dx%d double]\n',name,size(temp,1),size(temp,2) );
          end
        else
          fprintf( fid, '%s[%dx%d double]\n',name,size(temp,1),size(temp,2) );
        end
      case iscell( temp ),
        if (numel(temp)<10 && (isvector(temp) || isscalar(temp)))
          fprintf( fid, '%s[%dx%d cell] = \n',name,size(temp,1),size(temp,2) );
          %disp(temp)
          for r =1:numel(temp)
            gen_object2file( fid, temp{r},indent + max_strlen + 2 );
            % JK - removed
            % fprintf( fid,'\n');
          end
        elseif (numel(temp)<10)
          fprintf( fid, '%s[%dx%d cell] = \n',name,size(temp,1),size(temp,2) );
          for r =1:size(temp,1)
            gen_object2file( fid, temp(r,:),indent + max_strlen + 2 );
          end
        else
          fprintf( fid, '%s[%dx%d cell]\n',name,size(temp,1),size(temp,2) );
        end
      case isstruct( temp ),  
        fprintf( fid, '%s[%dx%d struct]\n',name,size(temp,1),size(temp,2) );
        if (indent<80)
          if (numel(temp)<10 && (isvector(temp) || isscalar(temp))) 
            gen_object2file( fid, temp,indent + max_strlen + 2 );
          elseif (numel(temp)<10)
            name2 = sprintf( name_format2,field_list{idx} );
            for r =1:size(temp,1)
              for c =1:size(temp,2)
                fprintf( fid, '%s(%d,%d) =\n',name2,r,c );
                gen_object2file( fid, temp(r,c),indent + max_strlen + 3 );
              end
            end
          end
        end
      case isobject( temp ),  fprintf( fid, '%s[inherent object]\n',name );
        if (indent<80)
          cmd = sprintf( 'display( obj_struct.%s,%d );',field_list{idx},indent + max_strlen + 2 );
          eval( cmd );
        end
      otherwise,
        fprintf( fid, '%s',name );
        try
          fprintf( fid, temp );
        catch %#ok<CTCH>
          fprintf( fid, '[No method to display type]' );
        end
        % JK - removed
        % fprintf( fid, '\n' );
    end
  end
  % JK - removed
  %if (length(obj_struct)>1), fprintf( fid,'\n'); end % added by JT
end                                             % added by JT