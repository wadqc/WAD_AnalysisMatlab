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

function [diameter_pix, centre_pix, figureHandle ] = WAD_MR_privateSizePos_pix( sImage, interpolPower, quiet )
% Fit a circle to the edge of the ACR phantom.
% To be used with plain slice that has NO features, e.g. middle slice.
%
% Input:    sImage        - single (WAD struct) instance entry with .filename
%           interpolPower - pixel matrix is interpolated with factor 2^interpolPower
%           quiet        - determines display of figure on screen or just
%                          save to disk in a quiet operation.
%
% Output:   diameter_pix - X and Y diameter IN PIXELS
%           centre_pix   - X and Y centre position of phantom
%           figureHandle - optional - handle to figure with image and
%                          overlay of fitted ellipse
%
% Algorithm:
% 0) image interpolation (optional)
% 1) edge detection using Canny edge filter:
%    - calculate norm of gradient
%    - thresholding on norm of gradient
%    - thinning of edge by one of following two options:
%      a) selection of pixel with largest gradient
%      b) find zero-crossing of 2nd derivative by sub-pixel interpolation
% 2) fit ellipse to detected/selected edge points
% 3) selection of points based on angle (to exclude edge pixels at location
%    of the air bubble in the phantom) and distance from fitted edge ( to
%    exclude falsely detected edge points (2nd and 3rd iteration). These 
%    parameters are currently hardcoded.
% 4) repeat steps 2 and 3 twice (three iterations in total)
%
% ------------------------------------------------------------------------
% SQVID MR
% file: SQ_MR_sizePos_pix.m
% ------------------------------------------------------------------------
% VUmc, Amsterdam, NL / Joost Kuijer / jpa.kuijer@vumc.nl
% 2009-11-16 / JK
% V0.84: added functionality for more robustness against artefacts:
% - remove edge points more than 20 pix away from estimated edge
% - added a second iteration of fit + selection of points
% - exclude distance in 2nd iteration set to 10 pixels
% ------------------------------------------------------------------------
% 2012-08-07 / JK / adapted to WAD
% ------------------------------------------------------------------------


% version info
my.name = 'WAD_MR_privateSizePos_pix';
my.version = '0.84';
my.date = '20120807';



% The canny edge detection algorithm parameters:
% 1. Parameters of edge detecting filters:
%    X-axis direction filter:
     Nx1=10;Sigmax1=1;Nx2=10;Sigmax2=1;Theta1=pi/2;
%    Y-axis direction filter:
     Ny1=10;Sigmay1=1;Ny2=10;Sigmay2=1;Theta2=0;
% 2. The thresholding parameter alfa:
     alfa=0.3; % 0.3

% Parameters for exclusion of edge pixels from ellipse fit
% exclude top angle because of the air bubble
excludeAngle_deg = 17.0;
% exclude pixels at a distance from fitted ellipse
excludedst_pix2 = 20; % 2nd iteration
excludedst_pix3 = 10; % 3rd iteration



% Get the initial image
fname = sImage.filename;
x = dicomread( fname );
    

% interpolate pixels with factor 2^interpolPower
% interpolPower = 1; % do we need interpolation? difference was 0.02%
w = interp2( double(x), interpolPower, '*cubic' ); % default
%w = double(x);

% create figure
if quiet 
    fig_visible = 'off';
else
    fig_visible = 'on';
end
% reasons for plotting a figure...
makefig = (nargout > 2) || ~quiet;

if makefig
    hFig = figure( 'Visible', fig_visible, 'MenuBar', 'none', 'Name', 'Geometry fit' );
    %hFig = figure( 'Name', 'Geometry fit' );
    colormap(gray);
    imagesc(w);
    axis image
    axis square
    axis off
    title(fname, 'Interpreter', 'none');
end

% X-axis direction edge detection
filterx=d2dgauss(Nx1,Sigmax1,Nx2,Sigmax2,Theta1);
Ix= conv2(w,filterx,'same');
%imagesc(Ix);
%title('Ix');

% Y-axis direction edge detection
filtery=d2dgauss(Ny1,Sigmay1,Ny2,Sigmay2,Theta2);
Iy=conv2(w,filtery,'same'); 
%imagesc(Iy);
%title('Iy');

% Norm of the gradient (Combining the X and Y directional derivatives)
NVI=sqrt(Ix.*Ix+Iy.*Iy);
%imagesc(NVI);
%title('Norm of Gradient');

%figure()
%imshow(NVI,[]);
%figure(hFig)

% Thresholding on the gradient
I_max=max(max(NVI));
I_min=min(min(NVI));
level=alfa*(I_max-I_min)+I_min;
Ibw=max(NVI,level.*ones(size(NVI)));
%Ibw=im2bw(NVI,graythresh(NVI));
%figure();
%imshow(Ibw,[level, I_max./2]);
%title('After Thresholding');
%figure()
% %hist(Ibw(:),50);
%figure(hFig);

% Thinning (Using interpolation to find the pixels where the norms of 
% gradient are local maximum.)
[n,m]=size(Ibw);
% Pre-allocate memory for faster performance
ellX = zeros(1,n*m);
ellY = zeros(1,n*m);

% 3-by-3 'grid' coordinates for 2D interpolation
X=[-1, 0,+1; -1, 0,+1; -1, 0,+1];
Y=[-1,-1,-1;  0, 0, 0; +1,+1,+1];
% index counter
ell_ic = 0;
% loop over the image
for i=2:n-1
    for j=2:m-1
        % if pixel is above threshold...
        if Ibw(i,j) > level
            % fill the 3-by-3 grid with the pixels around the current pix
            % ... data here is the norm of the gradient.
            Z=[ Ibw(i-1,j-1), Ibw(i-1,j), Ibw(i-1,j+1);
                Ibw(i,  j-1), Ibw(i,  j), Ibw(i,  j+1);
                Ibw(i+1,j-1), Ibw(i+1,j), Ibw(i+1,j+1) ];
            % next lines define 2 points on a unit circle around the
            % current pixel, along the direction of the maximum gradient
            XI=[Ix(i,j)/NVI(i,j), -Ix(i,j)/NVI(i,j)];
            YI=[Iy(i,j)/NVI(i,j), -Iy(i,j)/NVI(i,j)];
            % interpolate the norm of the gradient at the above-defined
            % points on the unit circle
            ZI=interp2(X,Y,Z,XI,YI);
            % check if current point is the local maximum, by checking its
            % value agains the value of the points on the unit circle.
            % Because the interpolated points were in the direction of the
            % max gradient, it must be a local maximum if they both are
            % smaller than ther current point.
            if Ibw(i,j) >= ZI(1) && Ibw(i,j) >= ZI(2)
                %I_temp(i,j)=I_max; %%%
                % store coordinates of thinned edge point
                ell_ic = ell_ic+1;
                ellX(ell_ic) = j;
                ellY(ell_ic) = i;
                % V0.91: interpolate along line of max gradient
                % to find zero-crossing of 2nd derivative (using linear
                % interpolation)
                %dl = -0.5 + (Ibw(i,j)-ZI(1)) ./ (2*Ibw(i,j)-ZI(1)-ZI(2));
                %ellX(ell_ic) = j + dl * (-Ix(i,j)/NVI(i,j));
                %ellY(ell_ic) = i + dl * (-Iy(i,j)/NVI(i,j));
            else
                %I_temp(i,j)=I_min; %%%
            end
        else
            %I_temp(i,j)=I_min; %%%
        end
    end
end
% figure();
% imshow(I_temp,[]);
% title('After Thinning');
% colormap(gray);
% figure(hFig);

% copy from pre-allocated memory to resized memory
ellX = ellX(1:ell_ic);
ellY = ellY(1:ell_ic);


% plot data & fit ellipse
%figure();
%plot( ellX, ellY, '.' );

% ----------------------------------------------------------------------
% stage 1: fit ellipse on full edge
% ----------------------------------------------------------------------
ellipse_t = fit_ellipse( ellX, ellY );

% ----------------------------------------------------------------------
% stage 2: select edge points
% ----------------------------------------------------------------------
ell1_ic = 0;
% V0.84: exclude points that are more than 20 pix (should roughly be 20 mm)
% away from detected radius to avoid false detection due to artefacts
avgdst = (ellipse_t.a + ellipse_t.b) / 2;
excludedst_pix = excludedst_pix2;
refdst = excludedst_pix * 2^interpolPower;

% Pre-allocate memory for faster performance
ellX1 = zeros(size(ellX));
ellY1 = zeros(size(ellY));

for i=1:ell_ic
    % exclude top angle because of the air bubble
    angle_deg = atan2( ellY(i) - ellipse_t.Y0, ellX(i) - ellipse_t.X0 ) / pi * 180.0;
    dst = abs( sqrt( (ellY(i) - ellipse_t.Y0).^2 + (ellX(i) - ellipse_t.X0 ).^2 ) - avgdst );
    if ( (angle_deg > -90+excludeAngle_deg) || (angle_deg < -90-excludeAngle_deg) ) ...
            && dst < refdst  % V0.84 added
        ell1_ic = ell1_ic + 1;
        ellX1(ell1_ic) = ellX(i);
        ellY1(ell1_ic) = ellY(i);
    end
end

% copy from pre-allocated memory to resized memory
ellX1 = ellX1(1:ell1_ic);
ellY1 = ellY1(1:ell1_ic);

% ----------------------------------------------------------------------
% stage 2: fit ellipse on selected edge
% ----------------------------------------------------------------------
ellipse_t = fit_ellipse( ellX1, ellY1 );

% ----------------------------------------------------------------------
% stage 3: re-select edge points based on stage 2 results
% ----------------------------------------------------------------------
ell1_ic = 0;
% V0.84: exclude points that are more than 10 pix (should roughly be 10 mm)
% away from detected radius to avoid false detection due to artefacts
avgdst = (ellipse_t.a + ellipse_t.b) / 2;
excludedst_pix = excludedst_pix3;
refdst = excludedst_pix * 2^interpolPower;

% Pre-allocate memory for faster performance
ellX1 = zeros(size(ellX));
ellY1 = zeros(size(ellY));

for i=1:ell_ic
    angle_deg = atan2( ellY(i) - ellipse_t.Y0, ellX(i) - ellipse_t.X0 ) / pi * 180.0;
    dst = abs( sqrt( (ellY(i) - ellipse_t.Y0).^2 + (ellX(i) - ellipse_t.X0 ).^2 ) - avgdst );
    if ( (angle_deg > -90+excludeAngle_deg) || (angle_deg < -90-excludeAngle_deg) ) ...
            && dst < refdst  % V0.84 added
        ell1_ic = ell1_ic + 1;
        ellX1(ell1_ic) = ellX(i);
        ellY1(ell1_ic) = ellY(i);
    end
end

% copy from pre-allocated memory to resized memory
ellX1 = ellX1(1:ell1_ic);
ellY1 = ellY1(1:ell1_ic);

% plot selected datapoints
%figure( 9 );
%imshow(w,[]);
%imshow(NVI,[]);
%hold on
%plot( ellX1, ellY1, '.r' );
%hold on
%plot( ellXi, ellYi, '.b' );
%figure(hFig);

% ----------------------------------------------------------------------
% stage 3: fit ellipse on selected edge
% ----------------------------------------------------------------------
if makefig
    ellipse_t = fit_ellipse( ellX1, ellY1, gca, excludeAngle_deg );
else
    ellipse_t = fit_ellipse( ellX1, ellY1 );
end

% output
diameter_pix(1) = (ellipse_t.a * 2) / 2^interpolPower;
diameter_pix(2) = (ellipse_t.b * 2) / 2^interpolPower;

centre_pix(1) = ellipse_t.X0 / 2^interpolPower;
centre_pix(2) = ellipse_t.Y0 / 2^interpolPower;

%[pathstr, name, ext] = fileparts(fname);
%saveas( gcf, fullfile(pathstr,'acrSize.jpg'));

% return figure handle if it was requested
if nargout > 2
    figureHandle = hFig;
end




% -------------------------------------------------------------------------
% Function d2dgauss:
% This function returns a 2D edge detector (first order derivative
% of 2D Gaussian function) with size n1*n2; theta is the angle that
% the detector rotated counter clockwise; and sigma1 and sigma2 are the
% standard deviation of the gaussian functions.
function h = d2dgauss(n1,sigma1,n2,sigma2,theta)
r=[cos(theta) -sin(theta);
   sin(theta)  cos(theta)];
for i = 1 : n2 
    for j = 1 : n1
        u = r * [j-(n1+1)/2 i-(n2+1)/2]';
        h(i,j) = gauss(u(1),sigma1)*dgauss(u(2),sigma2);
    end
end
h = h / sqrt(sum(sum(abs(h).*abs(h))));

% Function "gauss.m":
function y = gauss(x,std)
y = exp(-x^2/(2*std^2)) / (std*sqrt(2*pi));

% Function "dgauss.m"(first order derivative of gauss function):
function y = dgauss(x,std)
y = -x * gauss(x,std) / std^2;
% -------------------------------------------------------------------------






%--------------------------------------------------------------------------
function ellipse_t = fit_ellipse( x,y,axis_handle, excludeAngle_deg )
%
% fit_ellipse - finds the best fit to an ellipse for the given set of points.
%
% Format:   ellipse_t = fit_ellipse( x,y,axis_handle )
%
% Input:    x,y         - a set of points in 2 column vectors. AT LEAST 5 points are needed !
%           axis_handle - optional. a handle to an axis, at which the estimated ellipse 
%                         will be drawn along with it's axes
%
% Output:   ellipse_t - structure that defines the best fit to an ellipse
%                       a           - sub axis (radius) of the X axis of the non-tilt ellipse
%                       b           - sub axis (radius) of the Y axis of the non-tilt ellipse
%                       phi         - orientation in radians of the ellipse (tilt)
%                       X0          - center at the X axis of the non-tilt ellipse
%                       Y0          - center at the Y axis of the non-tilt ellipse
%                       X0_in       - center at the X axis of the tilted ellipse
%                       Y0_in       - center at the Y axis of the tilted ellipse
%                       long_axis   - size of the long axis of the ellipse
%                       short_axis  - size of the short axis of the ellipse
%                       status      - status of detection of an ellipse
%
% Note:     if an ellipse was not detected (but a parabola or hyperbola), then
%           an empty structure is returned

% =====================================================================================
%                  Ellipse Fit using Least Squares criterion
% =====================================================================================
% We will try to fit the best ellipse to the given measurements. the mathematical
% representation of use will be the CONIC Equation of the Ellipse which is:
% 
%    Ellipse = a*x^2 + b*x*y + c*y^2 + d*x + e*y + f = 0
%   
% The fit-estimation method of use is the Least Squares method (without any weights)
% The estimator is extracted from the following equations:
%
%    g(x,y;A) := a*x^2 + b*x*y + c*y^2 + d*x + e*y = f
%
%    where:
%       A   - is the vector of parameters to be estimated (a,b,c,d,e)
%       x,y - is a single measurement
%
% We will define the cost function to be:
%
%   Cost(A) := (g_c(x_c,y_c;A)-f_c)'*(g_c(x_c,y_c;A)-f_c)
%            = (X*A+f_c)'*(X*A+f_c) 
%            = A'*X'*X*A + 2*f_c'*X*A + N*f^2
%
%   where:
%       g_c(x_c,y_c;A) - vector function of ALL the measurements
%                        each element of g_c() is g(x,y;A)
%       X              - a matrix of the form: [x_c.^2, x_c.*y_c, y_c.^2, x_c, y_c ]
%       f_c            - is actually defined as ones(length(f),1)*f
%
% Derivation of the Cost function with respect to the vector of parameters "A" yields:
%
%   A'*X'*X = -f_c'*X = -f*ones(1,length(f_c))*X = -f*sum(X)
%
% Which yields the estimator:
%
%       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%       |  A_least_squares = -f*sum(X)/(X'*X) ->(normalize by -f) = sum(X)/(X'*X)  |
%       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%
% (We will normalize the variables by (-f) since "f" is unknown and can be accounted for later on)
%  
% NOW, all that is left to do is to extract the parameters from the Conic Equation.
% We will deal the vector A into the variables: (A,B,C,D,E) and assume F = -1;
%
%    Recall the conic representation of an ellipse:
% 
%       A*x^2 + B*x*y + C*y^2 + D*x + E*y + F = 0
% 
% We will check if the ellipse has a tilt (=orientation). The orientation is present
% if the coefficient of the term "x*y" is not zero. If so, we first need to remove the
% tilt of the ellipse.
%
% If the parameter "B" is not equal to zero, then we have an orientation (tilt) to the ellipse.
% we will remove the tilt of the ellipse so as to remain with a conic representation of an 
% ellipse without a tilt, for which the math is more simple:
%
% Non tilt conic rep.:  A`*x^2 + C`*y^2 + D`*x + E`*y + F` = 0
%
% We will remove the orientation using the following substitution:
%   
%   Replace x with cx+sy and y with -sx+cy such that the conic representation is:
%   
%   A(cx+sy)^2 + B(cx+sy)(-sx+cy) + C(-sx+cy)^2 + D(cx+sy) + E(-sx+cy) + F = 0
%
%   where:      c = cos(phi)    ,   s = sin(phi)
%
%   and simplify...
%
%       x^2(A*c^2 - Bcs + Cs^2) + xy(2A*cs +(c^2-s^2)B -2Ccs) + ...
%           y^2(As^2 + Bcs + Cc^2) + x(Dc-Es) + y(Ds+Ec) + F = 0
%
%   The orientation is easily found by the condition of (B_new=0) which results in:
% 
%   2A*cs +(c^2-s^2)B -2Ccs = 0  ==> phi = 1/2 * atan( b/(c-a) )
%   
%   Now the constants   c=cos(phi)  and  s=sin(phi)  can be found, and from them
%   all the other constants A`,C`,D`,E` can be found.
%
%   A` = A*c^2 - B*c*s + C*s^2                  D` = D*c-E*s
%   B` = 2*A*c*s +(c^2-s^2)*B -2*C*c*s = 0      E` = D*s+E*c 
%   C` = A*s^2 + B*c*s + C*c^2
%
% Next, we want the representation of the non-tilted ellipse to be as:
%
%       Ellipse = ( (X-X0)/a )^2 + ( (Y-Y0)/b )^2 = 1
%
%       where:  (X0,Y0) is the center of the ellipse
%               a,b     are the ellipse "radiuses" (or sub-axis)
%
% Using a square completion method we will define:
%       
%       F`` = -F` + (D`^2)/(4*A`) + (E`^2)/(4*C`)
%
%       Such that:    a`*(X-X0)^2 = A`(X^2 + X*D`/A` + (D`/(2*A`))^2 )
%                     c`*(Y-Y0)^2 = C`(Y^2 + Y*E`/C` + (E`/(2*C`))^2 )
%
%       which yields the transformations:
%       
%           X0  =   -D`/(2*A`)
%           Y0  =   -E`/(2*C`)
%           a   =   sqrt( abs( F``/A` ) )
%           b   =   sqrt( abs( F``/C` ) )
%
% And finally we can define the remaining parameters:
%
%   long_axis   = 2 * max( a,b )
%   short_axis  = 2 * min( a,b )
%   Orientation = phi
%
%

% initialize
orientation_tolerance = 1e-3;

% empty warning stack
lastwarn( '' );

% prepare vectors, must be column vectors
x = x(:);
y = y(:);

% remove bias of the ellipse - to make matrix inversion more accurate. (will be added later on).
mean_x = mean(x);
mean_y = mean(y);
x = x-mean_x;
y = y-mean_y;

% the estimation for the conic equation of the ellipse
% VUMC - JK: modified not to rotate the ellipse; removed the x*y term
% VUMC - JK: X = [x.^2, x.*y, y.^2, x, y ];
X = [x.^2, y.^2, x, y ];
a = sum(X)/(X'*X);

% check for warnings
if ~isempty( lastwarn )
    disp( 'stopped because of a warning regarding matrix inversion' );
    ellipse_t = [];
    return
end

% extract parameters from the conic equation
% VUMC - JK: [a,b,c,d,e] = deal( a(1),a(2),a(3),a(4),a(5) );
[a,c,d,e] = deal( a(1),a(2),a(3),a(4) );
b = 0.0; % no rotation

% remove the orientation from the ellipse
if ( min(abs(b/a),abs(b/c)) > orientation_tolerance )
    orientation_rad = 1/2 * atan( b/(c-a) );
    cos_phi = cos( orientation_rad );
    sin_phi = sin( orientation_rad );
    [a,b,c,d,e] = deal(...
        a*cos_phi^2 - b*cos_phi*sin_phi + c*sin_phi^2,...
        0,...
        a*sin_phi^2 + b*cos_phi*sin_phi + c*cos_phi^2,...
        d*cos_phi - e*sin_phi,...
        d*sin_phi + e*cos_phi );
    [mean_x,mean_y] = deal( ...
        cos_phi*mean_x - sin_phi*mean_y,...
        sin_phi*mean_x + cos_phi*mean_y );
else
    orientation_rad = 0;
    cos_phi = cos( orientation_rad );
    sin_phi = sin( orientation_rad );
end

% check if conic equation represents an ellipse
test = a*c;
switch (1)
case (test>0),  status = '';
case (test==0), status = 'Parabola found';  warning( 'fit_ellipse: Did not locate an ellipse' );
case (test<0),  status = 'Hyperbola found'; warning( 'fit_ellipse: Did not locate an ellipse' );
end

% if we found an ellipse return it's data
if (test>0)
    
    % make sure coefficients are positive as required
    if (a<0), [a,c,d,e] = deal( -a,-c,-d,-e ); end
    
    % final ellipse parameters
    X0          = mean_x - d/2/a;
    Y0          = mean_y - e/2/c;
    F           = 1 + (d^2)/(4*a) + (e^2)/(4*c);
    [a,b]       = deal( sqrt( F/a ),sqrt( F/c ) );    
    long_axis   = 2*max(a,b);
    short_axis  = 2*min(a,b);

    % rotate the axes backwards to find the center point of the original TILTED ellipse
    R           = [ cos_phi sin_phi; -sin_phi cos_phi ];
    P_in        = R * [X0;Y0];
    X0_in       = P_in(1);
    Y0_in       = P_in(2);
    
    % pack ellipse into a structure
    ellipse_t = struct( ...
        'a',a,...
        'b',b,...
        'phi',orientation_rad,...
        'X0',X0,...
        'Y0',Y0,...
        'X0_in',X0_in,...
        'Y0_in',Y0_in,...
        'long_axis',long_axis,...
        'short_axis',short_axis,...
        'status','' );
else
    % report an empty structure
    ellipse_t = struct( ...
        'a',[],...
        'b',[],...
        'phi',[],...
        'X0',[],...
        'Y0',[],...
        'X0_in',[],...
        'Y0_in',[],...
        'long_axis',[],...
        'short_axis',[],...
        'status',status );
end

% check if we need to plot an ellipse with it's axes.
if (nargin>2) && ~isempty( axis_handle ) && (test>0)
    
    % rotation matrix to rotate the axes with respect to an angle phi
    R = [ cos_phi sin_phi; -sin_phi cos_phi ];
    
    % the axes
    ver_line        = [ [X0 X0]; Y0+b*[-1 1] ];
    horz_line       = [ X0+a*[-1 1]; [Y0 Y0] ];
    new_ver_line    = R*ver_line;
    new_horz_line   = R*horz_line;
    
    % the ellipse
    excludeAngle_rad = excludeAngle_deg / 180 * pi;
    theta_r         = linspace( -0.5*pi + excludeAngle_rad, 1.5*pi - excludeAngle_rad );
    ellipse_x_r     = X0 + a*cos( theta_r );
    ellipse_y_r     = Y0 + b*sin( theta_r );
    rotated_ellipse = R * [ellipse_x_r;ellipse_y_r];
    
    % draw
    hold_state = get( axis_handle,'NextPlot' );
    set( axis_handle,'NextPlot','add' );
    % Fixed v0.83 add 0.5 offset for correct overlay with image
    % Note: not needed for overlay on norm-of-gradient image!
    plot( new_ver_line(1,:)+0.5,new_ver_line(2,:)+0.5,'r' );
    plot( new_horz_line(1,:)+0.5,new_horz_line(2,:)+0.5,'r' );
    plot( rotated_ellipse(1,:)+0.5,rotated_ellipse(2,:)+0.5,'r' );
    %plot( new_ver_line(1,:),new_ver_line(2,:),'r' );
    %plot( new_horz_line(1,:),new_horz_line(2,:),'r' );
    %plot( rotated_ellipse(1,:),rotated_ellipse(2,:),'r' );
    set( axis_handle,'NextPlot',hold_state );
end
