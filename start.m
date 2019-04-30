%% Get list of videos
close all; clear;

cd('C:\videos\rat1\');
videos = ls('*.avi');
videos = sort_nat(cellstr(videos));
trialNum = length(videos); % no. of trials/videos

%% set ROI for analysis
% Set area of video to analyze. Adjust ROI if necessary.
v = VideoReader(videos{1}); % get first video on list
figure
rgbFrame=read(v,1);
rgbFrame = flipdim(rgbFrame,2); % flip video if rat is right-handed
imshow(rgbFrame)
title('Click on top left, then bottom right of ROI')
roi = ginput(2);
hold on
rectangle('Position',[roi(1,1) roi(1,2) roi(2,1)-roi(1,1) roi(2,2)-roi(1,2)],'EdgeColor','r');

%% set wall and pellet positions
rgbFrame=rgbFrame(roi(1,2):roi(2,2),roi(1,1):roi(2,1),:); % crop frame
figure
imshow(rgbFrame)
% get coordinates roi of front wall, where hand might be occluded. Make
% wall ROI slightly wider than wall, such that pixels of hand will overlap
% with ROI.
title('Select front wall')
wall = ginput(4); 
% get coordinates of pellet
title('Select pellet')
pellet = ginput(4); 

hold on
plot(wall(:,1),wall(:,2))
plot(pellet(:,1),pellet(:,2))

%% auto paw tracking

% initialize outputs
trial.traj=[];
trial.area=[];
trial.pixel=[];

% set options
options.redThresh=0.14;
options.crop=[roi(1,1) roi(1,2) roi(2,1)-roi(1,1) roi(2,2)-roi(1,2)];
options.rh=0;
options.plotdisp=0;
options.wallCorrect=1;
options.wall=wall;

for i = 1:trialNum % loop over trials
    x=tic;
    
    v = VideoReader(videos{i});
    
    % get trajectory
    [hold_path, hold_area, hold_pixel] = handTrack(v,options);
    
    trial(i).traj = hold_path;
    trial(i).area = hold_area;
    trial(i).pixel = hold_pixel;
    
    fprintf('%i %s %i %.2d \n',i,'/',trialNum,toc(x));
end

save video_markings trial options wall pellet trialNum videos

%% auto pellet and retract markers

for i=1:trialNum
    hold_pixel=trial(i).pixel;
    hold_pixel(cellfun(@isempty, hold_pixel))={[0,0]};
    pelletTouch=cellfun(@(x) sum(inpolygon(x(:,1),x(:,2),pellet(:,1),pellet(:,2))),hold_pixel);
    tmp=find(pelletTouch>5);
    if ~isempty(tmp)
        trial(i).pellet=tmp(1); % first frame that overlaps with pellet 
        trial(i).pelletOverlap=tmp;
    end
    tmp=find(pelletTouch>=1);
     if ~isempty(tmp)
        trial(i).retract=tmp(end)+2; % second frame that stops overlapping with pellet
    end
end
save video_markings trial -append

%% kinematics marking
% GUI to adjust/add trajectories and markers

trial_new=trial;

%options.crop=[x1 dx y1 dy];
options.rh=0;
options.videoname = 'Rat';
options.trialtot = trialNum;

for i = 1:trialNum % loop over trials

    % set trial options
    v = VideoReader(videos{i}); 
    options.trialnum = i;
    exit = 0;
    [flags,points,acc,movquals] = kinematicsGUI(v,trial_new(i),options);
    while ~exit
        pause(1);
    end
    trial_new(i).traj = points;
    trial_new(i).movStart = flags{1};
    trial_new(i).reach = flags{2};
    trial_new(i).pellet = flags{3};
    trial_new(i).grasp = flags{4};
    trial_new(i).retract = flags{5};
    trial_new(i).movEnd = flags{6};
    trial_new(i).acc = acc;
    trial_new(i).movQual = movquals;
    
end

save video_markings trial_new -append