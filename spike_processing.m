

%% load raw data

% raw data available on
% https://drive.google.com/drive/folders/1CwFcErgp3F3D6I2TB_hTtW1JAQB21TAC?usp=sharing
%
datapath='/home/jvoigts/Dropbox (MIT)/tenss/tenss_2017_lectures_data/Ringo/2017-06-14_12-56-12/'


data_raw=[];
for ch=[1:4]+12 % grab 4 channels of raw data from one tetrode
    fname=sprintf('100_CH%d.continuous',ch)
    [data, timestamps, info]=load_open_ephys_data_faster(fullfile(datapath,fname));
    data_raw(:,end+1) = data;
end;

data_raw=data_raw.*info.header.bitVolts;
fs = info.header.sampleRate;

%data_raw=data_raw(1:30000,:); % cut away some data for faster testing

%% plot

plotlim=100000;
figure(1);
clf;
hold on;
plot(data_raw(1:plotlim,:));


%% filter

clf; hold on;
[b,a] = butter(3, [300 3000]/(fs/2)); % choose filter (normalize bp freq. to nyquist freq.)

data_bp=filter(b,a,data_raw); %apply filter in one direction

plot(data_bp(1:plotlim,:));

% find treshold crossings
treshold=20;
crossed= min(data_bp,[],2)<-treshold; % trigger if _any_ channel crosses in neg. direction

spike_onsets=find(diff(crossed)==1);

length_sec=size(data,1)/fs;
fprintf('got %d candidate events in %dmin of data, ~%.2f Hz\n',numel(spike_onsets),round(length_sec/60),numel(spike_onsets)/length_sec)

for i=1:numel(spike_onsets)
    if(spike_onsets(i)<plotlim)
        plot([1 1].*spike_onsets(i),[-1 1].*treshold*2,'k--')
    end;
end;


%% extract spike waveforms and make some features

spike_window=[1:32]-5; % grab some pre-treshold crossign samples

spikes=[];
spikes.waveforms=zeros(numel(spike_onsets),4*numel(spike_window)); % pre-allocate memory
spikes.peakamps=zeros(numel(spike_onsets),4);
spikes.times = spike_onsets/(fs/1000);

for i=1:numel(spike_onsets)
    this_spike=(data_bp(spike_onsets(i)+spike_window,:));
    
    spikes.waveforms(i,:)= this_spike(:);% grab entire waveform
    spikes.peakamps(i,:)=min(this_spike); % grab 4 peak amplitudes
end;


%% plot peak to peak amplitudes
clf; hold on;
plot(spikes.peakamps(:,2),spikes.peakamps(:,4),'.');
daspect([1 1 1]);

%% initialize all cluster assignments to 1
spikes.cluster=ones(numel(spike_onsets),1);

%% manual spike sorter
% cluster 0 shall be the noise cluster (dont plot this one)
run =1;

cmap=jet;
projections=[1 2; 1 3; 1 4; 2 3; 2 4; 3 4]; % possible feature projections
use_projection=1;

cluster_selected=2;

while run
    dat_x=spikes.peakamps(:,projections(use_projection,1));
    dat_y=spikes.peakamps(:,projections(use_projection,2));
    
    clf; 
    subplot(2,3,1); hold on;% plot mean waveform
    plot(quantile(spikes.waveforms(spikes.cluster(ii)==cluster_selected,:),.2),'g');
    plot(quantile(spikes.waveforms(spikes.cluster(ii)==cluster_selected,:),.5),'k');
    plot(quantile(spikes.waveforms(spikes.cluster(ii)==cluster_selected,:),.8),'g');
    title('waveforms from cluster');
    
    subplot(2,3,4); hold on;% plot isi distribution
    isi = diff(spikes.times(spikes.cluster(ii)==cluster_selected));
    bins=linspace(0.5,10,20); 
    h= hist(isi,bins); h(end)=0;
    stairs(bins,h);
    
    
    ax=subplot(2,3,[2 3 5 6]); hold on; % plot main feature display
    ii=spikes.cluster>0; % dont plot noise cluster
    scatter(dat_x(ii),dat_y(ii),(1+(spikes.cluster(ii)==cluster_selected))*10,spikes.cluster(ii)*2,'filled');
    title(sprintf('current cluster %d',cluster_selected));
    
    [x,y,b]=ginput(1);
    
    if b>47 & b <58 % number keys, cluster select
        cluster_selected=b-48;
    end;
    
    if b==30; use_projection=mod(use_projection,6)+1; end; % up/down: cycle trough projections
    if b==31; use_projection=mod(use_projection-2,6)+1; end; % up/down: cycle trough projections
    if b==27; disp('exited'); run=0; end; % esc: exit
    
    if b==43; % +, add to cluster
        t= imfreehand(ax,'Closed' ,1);
        t.setClosed(1);
        r=t.getPosition;
        px=r(:,1);py=r(:,2);
        in = inpolygon(dat_x,dat_y,px,py);
        spikes.cluster(in)=cluster_selected;
    end;
    
end;