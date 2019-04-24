function [hold_path, hold_area, hold_pixel] = handTrack_LG1706(v,options)
% Detects and tracks red-painted rat paw
% Usage: [path, area, pixel] = handTrack_LG170615(v,options)
% Inputs:
%   v: video object
%   options: structured array of options with fields:
%       redThresh: threshold value for red paw detection
%       crop: area of video to analysis, 4*1 vector in the form [x dx y dy]
%       trialFrames: number of frames in video, optional if trials are not
%       concatenated
%       trialFrameInd: frame of video to start at -1, default 0 (starts at
%       1)
%       rh: Set to 1 if rat is RH. Flips video for analysis. Default 0.
%       plotdisp: Set to 1 to plot hand tracking process. Default 1.
%       wallCorrect: Set to 1 to correct for front wall obstructing hand
%       wall: 4*2 matrix of wall coordinates, must be set if wallCorrect =
%       1
% Outputs:
%   path: x,y coordinates of hand trajectory over frames (nFrames*2)
%   area: no. of pixels of hand (nFrames*1)
%   pixel: list of hand pixel coordinates for each frame, nFrames*1 cell
%   array of nPixels*2

% set default options if no options provided
if ~isfield(options,'redThresh')
    options.redThresh = 0.15;
end
if ~isfield(options,'crop')
    options.crop = [200,400,150,300];
end
if ~isfield(options,'trialFrames')
    options.trialFrames = get(v,'NumberOfFrames');
end
if ~isfield(options,'trialFrameInd')
    options.trialFrameInd = 0;
end
if ~isfield(options,'rh')
    options.rh = 0;
end
if ~isfield(options,'plotdisp')
    options.plotdisp = 1;
end
if ~isfield(options,'wallCorrect')
    options.wallCorrect = 1;
end
if options.wallCorrect && ~isfield(options,'wall')
    error('Error. Wall correction is on but wall ROI not specified.')
end

% initialize outputs
hold_path=nan(options.trialFrames,2);
hold_area=nan(options.trialFrames,1);
hold_pixel=cell(options.trialFrames,1);

if options.plotdisp == 1
    close all;
    figure('units','normalized','outerposition',[0.1 0.5 .8 .5])
end

for j=1:options.trialFrames % loop over frames in trial
    rgbFrame=read(v,options.trialFrameInd+j); % read frame
    
    if options.rh
        rgbFrame = flipdim(rgbFrame,2); % flip if right handed to keep consistent
    end
    
    % crop frame
    rgbFrame=rgbFrame(options.crop(3):(options.crop(3)+options.crop(4)),options.crop(1):(options.crop(1)+options.crop(2)),:);     
    
    diffFrameRed = imsubtract(rgbFrame(:,:,1), rgb2gray(rgbFrame)); % Get red component of the image
    diffFrameRed = medfilt2(diffFrameRed, [2 2]); % Filter out the noise by using median filter
    binFrameRed = im2bw(diffFrameRed, options.redThresh); % Convert the image into binary image with the red objects as white
    
    %     diffFrameBlue = imsubtract(rgbFrame(:,:,3), rgb2gray(rgbFrame)); % Get blue component of the image
    %     diffFrameBlue = medfilt2(diffFrameBlue, [2 2]); % Filter out the noise by using median filter
    %     binFrameBlue = im2bw(diffFrameBlue, blueThresh); % Convert the image into binary image with the blue objects as white
    
    ext=regionprops(binFrameRed,'FilledArea','Centroid','PixelList');
    filledArea=cat(1,ext.FilledArea);
    centroid=cat(1,ext.Centroid);
    [A,B]=sort(filledArea,'descend'); %find the biggest one
    
    if options.plotdisp==1 % plots hand tracking
        subplot(1,3,1);
        imshow(rgbFrame);
    end
    
    if ~isempty(B) && A(1)>100 && ~isempty(centroid) %if there are areas >100 pixels
        
        if options.wallCorrect
            %%% check if wall is obstructing part of hand
            % calculate area overlap with wall
            pixelList={ext.PixelList}';
            overlap = cellfun(@(x) inpolygon(x(:,1),x(:,2),options.wall(:,1),options.wall(:,2)),pixelList,'UniformOutput',0);
            overlapAreaInd = find(cellfun(@sum, overlap)>5); % areas with more than 5 pixel overlap
            
            if length(B)>1 && length(overlapAreaInd)>1 % if more than one area overlap with wall
                % find the index of the two largest areas that overlapped wall
                [~,tmp]=intersect(B,overlapAreaInd); 
                tmp2=sort(tmp);
                ind1=B(tmp2(1)); % largest area that overlapped wall
                ind2=B(tmp2(2)); % second largest area that overlapped
                
                if abs(centroid(ind1,2)-centroid(ind2,2))<25 % if the two areas are close in y direction
                    % get pixels in the overlap from both areas
                    tmpPixels=cat(1,ext(ind1).PixelList(overlap{ind1},:),ext(ind2).PixelList(overlap{ind2},:));
                    k=boundary(tmpPixels(:,1),tmpPixels(:,2)); % find boundary of the two overlap areas
                    % create mask based on boundary
                    tmpMask = poly2mask(tmpPixels(k,1),tmpPixels(k,2),size(binFrameRed,1),size(binFrameRed,2));
                    binFrameRed(tmpMask)=1; % fill area occluded by wall
                    
                    % recalculate threshold areas
                    ext=regionprops(binFrameRed,'FilledArea','Centroid','PixelList');
                    filledArea=cat(1,ext.FilledArea);
                    centroid=cat(1,ext.Centroid);
                    [A,B]=sort(filledArea,'descend');
                end
            end
            %%% end of hand obstruction correction
        end
        
        hand_pos=centroid(B(1),:);
        hold_path(j,:)=hand_pos;
        hold_area(j)=A(1);
        hold_pixel{j}=ext(B(1)).PixelList;
        
        if options.plotdisp==1 % plots hand tracking
            
            subplot(1,3,2);
            imshow(binFrameRed);
            
            for plot_val=1:2
                subplot(1,3,plot_val);
                rectangle('Position',[hand_pos(1)-25 hand_pos(2)-25 50 50],'EdgeColor','r');
            end
            
            subplot(1,3,3);
            f_step=30;
            
            if hand_pos(1) < f_step+1
                hand_pos(1) = f_step+1;
            end
            if hand_pos(1) > size(rgbFrame,2)-f_step-1
                hand_pos(1) = size(rgbFrame,2)-f_step-1;
            end
            if hand_pos(2) < f_step+1
                hand_pos(2) = f_step+1;
            end
            if hand_pos(2) > size(rgbFrame,1)-f_step-1
                hand_pos(2) = size(rgbFrame,1)-f_step-1;
            end
            hand_pos=round(hand_pos);
            hand_view=rgbFrame((hand_pos(2)-f_step):(hand_pos(2)+f_step),(hand_pos(1)-f_step):(hand_pos(1)+f_step),:);
            imshow(hand_view);
            
            %subplot(1,3,1); hold on
            %plot(hold_path(end-4:end,1),hold_path(end-4:end,2),'g','LineWidth',3)
            %subplot(1,3,2); hold on
            %plot(hold_path(end-4:end,1),hold_path(end-4:end,2),'g','LineWidth',3)
        end
        
    end
    if options.plotdisp == 1
        pause(0.05)
    end
    
end