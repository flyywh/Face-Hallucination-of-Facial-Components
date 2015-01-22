function [ imHR, ori_HR, im_rgb, imB, imBicubic, Type, idx, dst, testset  ] = pre_process( imHR, compf, compp, nn, par, index, parameters, lm )

    [im_h, im_w,dummy] = size(imHR);
    im_h = floor((im_h )/par.nFactor)*par.nFactor ;
    im_w = floor((im_w )/par.nFactor)*par.nFactor ;
    imHR=imHR(1:im_h,1:im_w,:);
   
    ori_HR = imHR;
    imMid = zeros( size(imHR) );
    if (size(imHR, 3) == 3)
        imHR = double(rgb2ycbcr( imHR ) );
        im_cb = imresize( imHR(:,:,2), 1/par.nFactor, 'Bicubic' );
        im_cr = imresize( imHR(:,:,3), 1/par.nFactor, 'Bicubic' );
        im_cb = imresize( im_cb, par.nFactor, 'Bicubic' );
        im_cr = imresize( im_cr, par.nFactor, 'Bicubic' );
        imMid(:,:,2) = im_cb;
        imMid(:,:,3) = im_cr;
    end
 
    imHR = double(imHR(:,:,1));
    
    psf                =     par.psf;            
    imLR = Blur('fwd', imHR, psf);
    imLR           =   imLR(1 : par.nFactor : im_h, 1 : par.nFactor : im_w);
    
    imMid(:,:,1) = imresize( imLR, par.nFactor, 'bicubic');
    imMid = ycbcr2rgb( uint8(imMid) );
    if isempty( lm ),
        try
            [bs, posemap] = F2_ReturnLandmarks( imMid, 'mi' );
        catch err
             disp('Error: The UCI algorithm does not detect a face.');
        end
        lm = F4_ConvertBStoMultiPieLandmarks(bs(1));
    end
 %   save_landmark_fig(bs, posemap, uint8(imMid), lm, ['tmp/Landmark',im_dir(img).name,'.png'] );
    if size(lm, 1) == 68,
       comp = compf;
    else
       comp = compp;
    end
  
    [CX CY] = meshgrid(1 : im_w, 1:im_h);
    [X Y] = meshgrid(1:par.nFactor:im_w, 1:par.nFactor:im_h);
    imBicubic  =   interp2(X, Y, imLR, CX, CY, 'spline');
    
      im_rgb = zeros(size(imBicubic));
      imB = zeros(size(imBicubic));
      imB(:,:,1) = imBicubic;
      if size(ori_HR, 3) == 3,
            im_rgb(:,:,2) = im_cb;
            im_rgb(:,:,3) = im_cr;
            imB(:,:,2) = im_cb;
            imB(:,:,3) = im_cr;
            imB = ycbcr2rgb( uint8( imB ) );
      end

    
    fprintf('Bicubic: %2.2f \n', csnr(imHR, imBicubic, 0, 0));
    
    hf1 = [-1,0,1];
    vf1 = [-1,0,1]'; 
    hf2 = [1,0,-2,0,1];
    vf2 = [1,0,-2,0,1]';
    
    Type = ones(size(imHR));   %belong to which component      
    for j = 1:4, 
            y1 = max(1+par.margin, floor(min(lm(comp{j},1))-par.lg));
            y2 = min(im_w-par.margin, ceil(max(lm(comp{j},1))+par.lg));
            x1 = max(1+par.margin, floor(min(lm(comp{j},2))-par.lg));
            x2 = min(im_h-par.margin, ceil(max(lm(comp{j},2))+par.lg));
            Type(x1:x2, y1:y2) = j+1;
    end
    Type = Type(1:size(imHR,1)-par.patch_size+1, 1:size(imHR,2)-par.patch_size+1);
    %Type = Type( size(imHR,1)-patch_size+1: size(imHR,1)-patch_size+1, 1:size(imHR,2)-patch_size+1);
    Type = Type(:);
    

   [v2 h1] = data2patch(conv2(double(imBicubic), vf2, 'same'), conv2(double(imBicubic), hf1, 'same'), par);
   [v1, h2] = data2patch(conv2(double(imBicubic), vf1, 'same'), conv2(double( imBicubic), hf2, 'same'), par);
   Tl = [h1;v1;h2;v2];
  
   vec_patches = Tl;
   testset = double(vec_patches);

    % fine nearest neighbors
    for i = 1:5,
           [idx{i},dst{i}] = flann_search(index{i},testset,nn,parameters{i});
    end
end

