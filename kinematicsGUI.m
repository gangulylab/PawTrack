function [flags,points,acc,movquals] = kinematicsGUI(v,trialinfo,options)
% GUI to visualize kinematics from video
% Allows user to modify/add trajectory and time markers
% If no prior trial info available, set trialinfo to []

%% options

if ~isfield(options,'crop')
    options.crop = [1,639,1,449];
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
if ~isfield(options,'videoname')
    options.videoname = 'Video';
end
if ~isfield(options,'trialnum')
    options.trialnum = 1;
end
if ~isfield(options,'trialtot')
    options.trialtot = 100;
end

curr_frame = options.trialFrameInd+1;
colors = [0,0,0; 1,0,0; 1,0,1; 0,0,1; 0,0.5,0; 0,0,0];

%% initialize outputs
% time markers
flags = cell(6,1); 
if ~isempty(trialinfo)
    if isfield(trialinfo,'movStart')
        flags{1}=trialinfo.movStart;
    end
    if isfield(trialinfo,'reach')
        flags{2}=trialinfo.reach;
    end
    if isfield(trialinfo,'pellet')
        flags{3}=trialinfo.pellet;
    end
    if isfield(trialinfo,'grasp')
        flags{4}=trialinfo.grasp;
    end
    if isfield(trialinfo,'retract')
        flags{5}=trialinfo.retract;
    end
    if isfield(trialinfo,'movEnd')
        flags{6}=trialinfo.movEnd;
    end
end
% trajectory    
if ~isempty(trialinfo) && isfield(trialinfo,'traj') && ~isempty(trialinfo.traj)
    points = trialinfo.traj; 
else
    points = NaN(options.trialFrames,2); 
end
% accuracy
if ~isempty(trialinfo) && isfield(trialinfo,'acc') && ~isempty(trialinfo.acc)
    acc=trialinfo.acc;
else
    acc=NaN;
end
% movement quality
if ~isempty(trialinfo) && isfield(trialinfo,'movQual') && ~isempty(trialinfo.movQual)
    movquals=trialinfo.movQual;
else
    movquals=ones(6,1).*-1;
end
%% create GUI

%%% figure %%%
fig = figure('Position',[100 100 1400 780],'Pointer','crosshair','KeyPressFcn',@keyPress_callback);

%%% plots %%%
% video
p1 = axes('Units','Pixels','Position',[40 240 640 480]);
rgbFrame=read(v,curr_frame); % read frame
if options.rh
    rgbFrame = flipdim(rgbFrame,2); % flip if right handed to keep consistent
end
rgbFrame=rgbFrame(options.crop(3):(options.crop(3)+options.crop(4)),options.crop(1):(options.crop(1)+options.crop(2)),:); % crop frame
img=imshow(rgbFrame);
set(img,'ButtonDownFcn',@p1_callback);
hold on
title([options.videoname, '  -----  Video: ', num2str(options.trialnum), ' out of ', num2str(options.trialtot), '  -----  Current Frame: ',num2str(curr_frame-options.trialFrameInd),' of ',num2str(options.trialFrames)])
trajPlot = plot(points(:,1), points(:,2),'g','linewidth',2);
pointPlot = plot(nan(1,1),nan(1,1),'o','linewidth',2,'markerfacecolor','y','markeredgecolor','k','markersize',10);
set(trajPlot,'ButtonDownFcn',@p1_callback);
set(pointPlot,'ButtonDownFcn',@p1_callback);

% xy coordinates
p2 = axes('Units','Pixels','Position',[740 520 640 200]);
p2_x=plot(points(:,1)); hold on; % x
p2_y=plot(points(:,2)); % y 
p2_ln=line([curr_frame-options.trialFrameInd curr_frame-options.trialFrameInd],[1 400],'Color','k'); % line showing current frame
for j = 1:6 % markers showing marked frames
    m(j)=plot(NaN,NaN,'*','Color',colors(j,:),'MarkerSize',10);
end
title('Trajectory x, y coordinates')
xlim([1 options.trialFrames])
ylim([1 400])
legend('x','y','Location','southeast')
set(p2,'ButtonDownFcn',@p2_callback);
set(p2_x,'ButtonDownFcn',@p2_callback);
set(p2_y,'ButtonDownFcn',@p2_callback);
set(p2_ln,'ButtonDownFcn',@p2_callback);
set(m(1:6),'ButtonDownFcn',@p2_callback);

% speed
p3 = axes('Units','Pixels','Position',[740 240 640 200]);
p3_plt = plot(speed(points));
hold on
p3_ln=line([curr_frame-options.trialFrameInd curr_frame-options.trialFrameInd],[0 35],'Color','k');
title('Speed')
xlim([1 options.trialFrames])
ylim([0 35])
set(p3,'ButtonDownFcn',@p3_callback);
set(p3_plt,'ButtonDownFcn',@p3_callback);
set(p3_ln,'ButtonDownFcn',@p3_callback);

%%% movement markers checkboxes %%%
buttons(1) = uicontrol('style','checkbox','position',[60 160 140 25],...
    'FontSize',10,'String','(1) Movement start');
buttons(2) = uicontrol('style','checkbox','position',[60 140 140 25],...
    'FontSize',10,'String','(2) Reach','ForegroundColor','r');
buttons(3) = uicontrol('style','checkbox','position',[60 120 140 25],...
    'FontSize',10,'String','(3) Pellet touch','ForegroundColor','m');
buttons(4) = uicontrol('style','checkbox','position',[60 100 140 25],...
    'FontSize',10,'String','(4) Grasp','ForegroundColor','b');
buttons(5) = uicontrol('style','checkbox','position',[60 80 140 25],...
    'FontSize',10,'String','(5) Retract','ForegroundColor',[0 0.5 0]);
buttons(6) = uicontrol('style','checkbox','position',[60 60 140 25],...
    'FontSize',10,'String','(6) Movement end');

%%% text fills for movement marker frames %%%
markerframes(1)=uicontrol('style','text','HorizontalAlignment','left','position',[200 160 100 20],'FontSize',10);
markerframes(2)=uicontrol('style','text','HorizontalAlignment','left','position',[200 140 100 20],'FontSize',10);
markerframes(3)=uicontrol('style','text','HorizontalAlignment','left','position',[200 120 100 20],'FontSize',10);
markerframes(4)=uicontrol('style','text','HorizontalAlignment','left','position',[200 100 100 20],'FontSize',10);
markerframes(5)=uicontrol('style','text','HorizontalAlignment','left','position',[200 80 100 20],'FontSize',10);
markerframes(6)=uicontrol('style','text','HorizontalAlignment','left','position',[200 60 100 20],'FontSize',10);
setMarkers;
clearBut=uicontrol('style','pushbutton','position',[210 20 80 20],'String','Clear All','FontSize',10,'Callback',@clearBut_callback);

%%% accuracy %%%
uicontrol('style','text','string','Accuracy','position',[560 160 60 20],'FontSize',10);
accVal = uicontrol('style','text','string',num2str(acc),'position',[640 160 30 20],'FontSize',10);

%%% movement quality analysis %%%
uicontrol('style','text','string','(Q) Digits open','position',[360 160 100 20],'FontSize',10,'HorizontalAlignment','left');
uicontrol('style','text','string','(W) Pronation','position',[360 140 100 20],'FontSize',10,'HorizontalAlignment','left');
uicontrol('style','text','string','(E) Grasp','position',[360 120 100 20],'FontSize',10,'HorizontalAlignment','left');
uicontrol('style','text','string','(R) Supination','position',[360 100 100 20],'FontSize',10,'HorizontalAlignment','left');
uicontrol('style','text','string','(T) Retract','position',[360 80 100 20],'FontSize',10,'HorizontalAlignment','left');
uicontrol('style','text','string','(Y) Release','position',[360 60 100 20],'FontSize',10,'HorizontalAlignment','left');
movqual(1)=uicontrol('style','text','HorizontalAlignment','left','position',[470 160 40 20],'FontSize',10);
movqual(2)=uicontrol('style','text','HorizontalAlignment','left','position',[470 140 40 20],'FontSize',10);
movqual(3)=uicontrol('style','text','HorizontalAlignment','left','position',[470 120 40 20],'FontSize',10);
movqual(4)=uicontrol('style','text','HorizontalAlignment','left','position',[470 100 40 20],'FontSize',10);
movqual(5)=uicontrol('style','text','HorizontalAlignment','left','position',[470 80 40 20],'FontSize',10);
movqual(6)=uicontrol('style','text','HorizontalAlignment','left','position',[470 60 40 20],'FontSize',10);
setMovQual;

%%% other push buttons %%%
clearTraj=uicontrol('style','pushbutton','position',[560 200 120 20],'String','Clear trajectory','FontSize',10,'Callback',@clearTraj_callback);

%% GUI functions

    function keyPress_callback(hObject, eventdata)
        
        button = double(fig.CurrentCharacter);
        movVals=[-1,0;0,0.5;0.5,1;1,-1];
        
        switch button
            
            % frame control
            case 28 %left arrow
                % back
                curr_frame = curr_frame-1;
                setFrame;
            case 29 %right arrow
                % forward
                curr_frame = curr_frame+1;
                setFrame;
            case 30 %down arrow
                % forward10
                curr_frame = curr_frame+10;
                setFrame;
            case 31 %up arrow
                % back10
                curr_frame = curr_frame-10;
                setFrame;
            case 100 % d
                ms = sort(cat(2,flags{:}));
                ms = ms - (curr_frame-options.trialFrameInd);
                ms = min(ms(ms>0));
                if ~isempty(ms)
                    curr_frame = curr_frame + ms;
                end
                setFrame;
            case 115 % s
                ms = sort(cell2mat(flags'));
                ms = ms - (curr_frame-options.trialFrameInd);
                ms = max(ms(ms<0));
                if ~isempty(ms)
                    curr_frame = curr_frame + ms;
                end
                setFrame;
                
            % frame flags (123456)
            case 49
                if (get(buttons(1),'value')==0)
                    set(buttons(1),'value',1);
                    flags{1}=[flags{1},curr_frame-options.trialFrameInd];
                else
                    set(buttons(1),'value',0);
                    flags{1}(flags{1}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
                
            case 50
                if (get(buttons(2),'value')==0)
                    set(buttons(2),'value',1);
                    flags{2}=[flags{2},curr_frame-options.trialFrameInd];
                else
                    set(buttons(2),'value',0);
                    flags{2}(flags{2}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
                
            case 51
                if (get(buttons(3),'value')==0)
                    set(buttons(3),'value',1);
                    flags{3}=[flags{3},curr_frame-options.trialFrameInd];
                else
                    set(buttons(3),'value',0);
                    flags{3}(flags{3}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
                
            case 52
                if (get(buttons(4),'value')==0)
                    set(buttons(4),'value',1);
                    flags{4}=[flags{4},curr_frame-options.trialFrameInd];
                else
                    set(buttons(4),'value',0);
                    flags{4}(flags{4}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
                
            case 53
                if (get(buttons(5),'value')==0)
                    set(buttons(5),'value',1);
                    flags{5}=[flags{5},curr_frame-options.trialFrameInd];
                else
                    set(buttons(5),'value',0);
                    flags{5}(flags{5}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
                
            case 54
                if (get(buttons(6),'value')==0)
                    set(buttons(6),'value',1);
                    flags{6}=[flags{6},curr_frame-options.trialFrameInd];
                else
                    set(buttons(6),'value',0);
                    flags{6}(flags{6}==(curr_frame-options.trialFrameInd))=[];
                end
                setMarkers;
            
            % movement quality (QWERTY)
            case 113
                [~,ind] = ismember(str2num(get(movqual(1),'string')),movVals(:,1));
                movquals(1)= movVals(ind,2);
                setMovQual;
            case 119
                [~,ind] = ismember(str2num(get(movqual(2),'string')),movVals(:,1));
                movquals(2)= movVals(ind,2);
                setMovQual;
            case 101
                [~,ind] = ismember(str2num(get(movqual(3),'string')),movVals(:,1));
                movquals(3)= movVals(ind,2);
                setMovQual;
            case 114
                [~,ind] = ismember(str2num(get(movqual(4),'string')),movVals(:,1));
                movquals(4)= movVals(ind,2);
                setMovQual;
            case 116
                [~,ind] = ismember(str2num(get(movqual(5),'string')),movVals(:,1));
                movquals(5)= movVals(ind,2);
                setMovQual;
            case 121
                [~,ind] = ismember(str2num(get(movqual(6),'string')),movVals(:,1));
                movquals(6)= movVals(ind,2);
                setMovQual;
                
            % spacebar for accuracy
            case 32 
                if isnan(acc)
                    acc=0;                    
                elseif acc==0
                    acc=1;
                elseif acc==1
                    acc=0;
                end
                set(accVal,'string',num2str(acc));
                
            % exit
            case 97 %a
                assignin('base','flags',flags);
                assignin('base','points',points);
                assignin('base','acc',acc);
                assignin('base','movquals',movquals);
                assignin('base','exit',1);
                close(fig);
        end
        
    end

    function p1_callback(hObject, eventdata)
        coords = get(p1,'CurrentPoint');
        coords = coords(1,1:2);
        type = get(fig,'SelectionType');
        
        if isequal(type,'normal')
            points(curr_frame-options.trialFrameInd,:)=coords;
            curr_frame = curr_frame+1;
        elseif isequal(type,'alt')
            points(curr_frame-options.trialFrameInd,:)=[NaN NaN];
        end
        setFrame;
        setCoordSpeed;
    end

    function p2_callback(hObject, eventdata)
        coords = get(p2,'CurrentPoint');
        coords = coords(1,1);
        curr_frame = options.trialFrameInd + round(coords);
        setFrame;
    end

    function p3_callback(hObject, eventdata)
        coords = get(p3,'CurrentPoint');
        coords = coords(1,1);
        curr_frame = options.trialFrameInd + round(coords);
        setFrame;
    end

    function clearBut_callback(hObject, eventdata)
        flags = cell(6,1);
        setFrame;
        setMarkers;
    end

    function clearTraj_callback(hObject, eventdata)
        points = NaN(options.trialFrames,2);
        setFrame;
    end

    function setFrame
        
        if curr_frame > options.trialFrameInd + options.trialFrames
            curr_frame = options.trialFrameInd + options.trialFrames;
        end
        
        if curr_frame <= options.trialFrameInd
            curr_frame = options.trialFrameInd+1;
        end
        
        % set video frame
        rgbFrame=read(v,curr_frame); % read frame
        if options.rh
            rgbFrame = flipdim(rgbFrame,2); % flip if right handed to keep consistent
        end
        
        rgbFrame=rgbFrame(options.crop(3):(options.crop(3)+options.crop(4)),options.crop(1):(options.crop(1)+options.crop(2)),:); % crop frame
        
        set(img,'cdata',rgbFrame);
        
        title(p1,[options.videoname, '  -----  Video: ', num2str(options.trialnum), ' out of ', num2str(options.trialtot), '  -----  Current Frame: ',num2str(curr_frame-options.trialFrameInd),' of ',num2str(options.trialFrames)])
        
        % set checkboxes
        set(buttons(1:6),'value',0);
        set(buttons(cellfun(@(x) ismember(curr_frame-options.trialFrameInd,x),flags)),'value',1);
        
        % set trajectory
        set(pointPlot,'xData',points(curr_frame-options.trialFrameInd,1));
        set(pointPlot,'yData',points(curr_frame-options.trialFrameInd,2));
        set(trajPlot,'xData',points(:,1));
        set(trajPlot,'yData',points(:,2));
        
        % set frame lines
        set(p2_ln,'xData',[curr_frame-options.trialFrameInd curr_frame-options.trialFrameInd]);
        set(p3_ln,'xData',[curr_frame-options.trialFrameInd curr_frame-options.trialFrameInd]);
    end

    function setMarkers
        for i=1:6
            set(markerframes(i),'string',num2str(flags{i}));
            if ~isempty(flags{i})
                set(m(i),'xData',flags{i});
                set(m(i),'yData',repmat(350,1,length(flags{i})));
            else
                set(m(i),'xData',NaN);
                set(m(i),'yData',NaN);
            end
        end
    end

    function setCoordSpeed
        set(p2_x,'yData',points(:,1));
        set(p2_y,'yData',points(:,2));
        set(p3_plt,'yData',speed(points));
    end

    function setMovQual
        for i = 1:6
            set(movqual(i),'string',movquals(i));
        end
    end

end

function out = speed(x)
    % calculates instantaneous speed
    out=sqrt(sum((x(2:end,:)-x(1:end-1,:)).^2,2));
end