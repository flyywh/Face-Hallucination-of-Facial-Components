function [Cp, Cs] = Smp_patch_blur_FC(patch_size, num_patch, par)
%sample patches for training set
addpath('Data');
addpath('Utilities');

load(['Data/Face_Training', par.training_set, '.mat']);

hf1 = [-1,0,1];
vf1 = [-1,0,1]';
% second order gradient filters
hf2 = [1,0,-2,0,1];
vf2 = [1,0,-2,0,1]';

[compf, compp] = Comp_lm(); %components landmarks of frontal and profile faces

img_num = size(images_hr, 3)-1;
nper_img = zeros(1, img_num);

for i = 1 : img_num
    imHR  =  images_hr(:,:,i);
    [im_h, im_w, ch]       =   size(imHR);
    if ch == 3,
        imHR = double( rgb2ycbcr( imHR ));
    end
    imHR = double(imHR(:,:,1));
    [im_h, im_w]       =   size(imHR);
    nper_img(i) = prod(size(imHR));
    
    [im_h, im_w,dummy] = size(imHR);
    im_h = floor((im_h )/par.nFactor)*par.nFactor ;
    im_w = floor((im_w )/par.nFactor)*par.nFactor ;
    imHR=imHR(1:im_h,1:im_w,:);
    
    psf                =     par.psf;             % The simulated PSF
    imLR = Blur('fwd', imHR, psf);
    imLR           =   imLR(1 : par.nFactor : im_h, 1 : par.nFactor : im_w);
  
    [CX CY] = meshgrid(1 : im_w, 1:im_h);
    [X Y] = meshgrid(1:par.nFactor:im_w, 1:par.nFactor:im_h);
    imBicubic  =   interp2(X, Y, imLR, CX, CY, 'spline');
    
    %fprintf('PSNR of Bicubic Training Image: %2.2f \n', csnr(imBicubic, imHR, 5, 5));
    HR_tr{i} = imHR;
    LR_Bicubic{i} = imBicubic;
end

nper_img = floor(nper_img*num_patch/sum(nper_img));
for i = 1:5,
    Cp{i} = [];
    Cs{i} = [];
    Pose{i} = [];
end

Mid = createIdx( size(HR_tr{i},1), size(HR_tr{i},2), patch_size );

for i = 1 : img_num    
   lm = landmarks(:,:,i);
   if lmnum(i) == 68,
       comp = compf;
   else
       comp = compp;
   end
   n = nper_img(i);
   [v1, h2] = data2patch(conv2(double(LR_Bicubic{i}), vf1, 'same'), conv2(double( LR_Bicubic{i}), hf2, 'same'), par);
   [h1 , v2] = data2patch( conv2(double( LR_Bicubic{i}), hf1, 'same'), conv2(double( LR_Bicubic{i}), vf2, 'same'), par);
   Tl = [h1;v1;h2;v2];
   
   [Th, ~] = data2patch( double( HR_tr{i} - LR_Bicubic{i}), conv2(double( HR_tr{i}), vf1, 'same'), par);
 
    idx = randperm(size(Th, 2));
    if size(Th, 2) < n,
        n = size(Th, 2)
    end
    Th1 = Th(:, idx(1:n));
    Tl1 = Tl(:, idx(1:n)); 
    pvars = var(Th1(1:patch_size*patch_size, :), 0, 1);
    idx = pvars > par.prunvar;
    Tl1 = Tl1(:, idx);
    Th1 = Th1(:, idx);
    Cs{1} = [Cs{1}, Th1];
    Cp{1} = [Cp{1}, Tl1];
  %  Pose{1} = [Pose{1}, ones(1, size(Th1, 2))*pose(i)];
    [im_h, im_w] = size( LR_Bicubic{i} );
    n = nper_img(i)/2;
    for j = 1:4,
        y1 = max(1+par.margin, floor(min(lm(comp{j},1))-par.lg));
        y2 = min(im_w-par.margin, ceil(max(lm(comp{j},1))+par.lg));
        x1 = max(1+par.margin, floor(min(lm(comp{j},2))-par.lg));
        x2 = min(im_h-par.margin, ceil(max(lm(comp{j},2))+par.lg));
        idx = Mid(x1:x2, y1:y2);
      %  fprintf('%d %d %d %d\n', x1, x2, y1, y2);
        Tl1 = Tl(:, idx(idx > 0));
        Th1 = Th(:, idx(idx > 0));
        idx = randperm(size(Th1, 2));
        if size(Th1, 2) < n,
            n = size(Th1, 2);
        end
        Th1 = Th1(:, idx(1:n));
        Tl1 = Tl1(:, idx(1:n)); 
        Cs{j+1} = [Cs{j+1}, Th1];
        Cp{j+1} = [Cp{j+1}, Tl1];
     %   Pose{j+1} = [Pose{j+1}, ones(1, size(Th1, 2))*pose(i)];
    end
    
    
end

for i = 1:5,
    Cp{i} = double(Cp{i});
    Cs{i} = double(Cs{i});
end

