function [traj, markers] = handTrackAndMarkers(v, coords, options)
% Takes coordinates of knuckle and wrist from DeepLabCut, returns
% trajectory of paw (average between knuckle and wrist) and frames where
% movement start, reach, pellet touch and retract occur. 
% LG last modified 20190710

%%% find trajectory %%%
% remove low likelihood points
coords(coords(:,3)<0.2 & coords(:,6)<0.2,:) = NaN;
% modify coords to fit crop
coords(:,[1,4]) = coords(:,[1,4]) - (options.crop(1)-1);
coords(:,[2,5]) = coords(:,[2,5]) - (options.crop(3)-1);
% remove negative coords
coords(coords(:,1)<0 | coords(:,2)<0 | coords(:,3)<0 | coords(:,4)<0,:) = NaN;

% trajectory -> take average between knuckle and wrist
traj.path = [mean(coords(:,[1,4]),2), mean(coords(:,[2,5]),2)];

%%% find reaches %%%
reach = [];
pass_wall = coords(:,1)<options.centerwall(1); % frames where knuckle is past slot
p1 = find(diff(pass_wall)==1)+1;
p2 = find(diff(pass_wall)==-1);
if length(p2)<length(p1) % if knuckle did not come back into box at the end of trial
    p2 = [p2; length(pass_wall)]; % artificially add a 'retract' into box
end
passes = [p1, p2(1:length(p1))]; % start and end indices
passes((passes(:,2)-passes(:,1))<3, :) = []; % remove short duration passes

if ~isempty(passes) % if there are reaches (where knuckle pass slot)
    hand_y = coords(:,2) - coords(:,5); % knuckle wrist y position difference
    hand_change = find(diff(hand_y < 0) == 1) + 1; % indices where hand transition from pointing down to up
    for j = 1:size(passes,1)
        if min(coords(passes(j,1):passes(j,2),1))<(options.centerwall(1)-3) % if knuckle goes more than 3 pixels past slot
            idx = find((hand_change - passes(j,1))<0);
            if isempty(idx)
                break
                %idx = find(min(hand_change - passes(j,1)));
            end
            reach = [reach, hand_change(idx(end))];
        end
    end
    reach = unique(reach); % remove repeats
end
markers.reach = reach;

if ~isempty(markers.reach) %if there are reaches
    
    %%% movement start %%%
    hand_x = coords(:,4)-coords(:,1);
    markers.movStart = [];
    lifts = find(diff(hand_x < 0.1) == 1);
    if ~isempty(lifts)
        markers.movStart = max(lifts((lifts - markers.reach(1)) <0)); % lift right before first reach
    end
    
    %%% pellet touch %%%
    % get pixels occupied by orange paw
    [~, ~, hold_pixel] = handTrack_LG1706(v,options);
    traj.pixel = hold_pixel;
    hold_pixel(cellfun(@isempty, hold_pixel))={[0,0]};
    pelletTouch=cellfun(@(x) sum(inpolygon(x(:,1),x(:,2),options.pellet(:,1),options.pellet(:,2))),hold_pixel)';
    [~, pks] = findpeaks(pelletTouch, 'MinPeakProminence', 10);
    p = [];
    if ~isempty(pks)
        r = [markers.reach, length(pelletTouch)];
        for j = 1:length(markers.reach)
            p = [p, round(mean(pks(pks>r(j) & pks <r(j+1))))];
        end
        p(isnan(p)) = [];
    end
    markers.pellet = p;
    
    %%% retract %%%
    retract_px = cellfun(@(x) sum(x(:,1)<options.arm(1)), hold_pixel);
    retract_px = find(retract_px == 0);
    retract = [];
    for j = 1:length(markers.pellet)
        retract = [retract, min(retract_px((retract_px - markers.pellet(j))>0))];
    end
    if length(retract)>1
        retract = unique(retract);
    end
    markers.retract = retract;
end
end