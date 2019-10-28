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
% get center of wall for reach amp calculation (center from just below
% pellet tray)
title('Select center of wall')
centerwall = ginput(1);
% get end of pellet arm 
title('Select end of pellet arm')
arm = ginput(1);

hold on
plot(wall(:,1),wall(:,2))
plot(pellet(:,1),pellet(:,2))

%% auto paw tracking

% read csv files (output from DLC)
csvs = dir('*.csv');
csvs = {csvs.name};
csvs = sort_nat(cellstr(csvs))';

% initialize outputs
trial.traj=[];
trial.area=[];
trial(trialNum).traj = [];

% set options
options.redThresh=0.14;
options.crop=[roi(1,1) roi(1,2) roi(2,1)-roi(1,1) roi(2,2)-roi(1,2)];
options.rh=0;
options.plotdisp=0;
options.wallCorrect=1;
options.wall=wall;
options.pellet=pellet;
options.arm=arm;
options.centerwall=centerwall;

for i = 1:trialNum % loop over trials
    x=tic;
    if ~isempty(csvs{i})
        %%% read csv %%%
        tmp = csvread([csvs{i}],3,1);
        
        %%% get time markers and traj %%%
        v = VideoReader(videos{i});
        
        [traj, markers] = handTrackAndMarkers(v, tmp, options);
        trial(i).traj = traj.path;
        trial(i).reach = markers.reach;
        if isfield(markers,'movStart')
            trial(i).movStart = markers.movStart;
        end
        if isfield(markers,'pellet')
            trial(i).pellet = markers.pellet;
            trial(i).retract = markers.retract;
            trial(i).pixel = traj.pixel;
        end
    end
    fprintf('%i %s %i %.2d \n',i,'/',trialNum,toc(x));
end

save video_markings trial options wall pellet trialNum videos

%% kinematics marking
% GUI to adjust/add trajectories and markers

trial_new=trial;

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