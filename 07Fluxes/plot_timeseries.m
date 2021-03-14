clearvars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%compute eddy:
%    - heat flux  T'v'
%    - momentum flux u'v'
%from Aeolus and MLS data, and (separately) ERA5 output
%
%
%the plotting code here has been through many cycles of modification and is
%hard to read - sorry about this, it works but it's just a bit messy
%
%Corwin Wright, c.wright@bath.ac.uk, 2021/01/13
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%data
Settings.InFile  = 'fluxes.mat';

%region to average over
Settings.LonRange = [-180,180];
Settings.LatRange = [55,75];
Settings.Levels   = p2h([50,100,150]);

%time series smoothing
Settings.SmoothDays = 5;

%normalise?
Settings.Normalise = 1;

%colours
cbrew = cbrewer('qual','Set1',9);

Colours.ReA = [0,0,0];
Colours.Obs = cbrew(5,:);
Colours.NoV = [1,1,1].*0.6;%cbrew(5,:);
Colours.Hyb = cbrew(2,:);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% main loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

k = 0; l= 0 ;clf; set(gcf,'color','w'); Letters = 'abgcdhefi';
subplot = @(m,n,p) subtightplot (m, n, p, [0.02,0.02], 0.15, 0.05);


for iLevel = 1:1:numel(Settings.Levels)

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% load data, and subset down to region
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  %load data
  Data = load(Settings.InFile);
  
  %shift times
  Data.Grid.TimeScale = Data.Grid.TimeScale-datenum(2021,1,5);
  
  %find region
  zidx   = closest(Data.Grid.HeightScale,Settings.Levels(iLevel));
  latidx = inrange(Data.Grid.LatScale,   Settings.LatRange);
  lonidx = inrange(Data.Grid.LonScale,   Settings.LonRange);
  
  %and subset. merge data to do in one pass
  a = cat(5,Data.HeatFlux.Obs,Data.HeatFlux.ReA,Data.MomFlux.Obs,Data.MomFlux.ReA,Data.HeatFlux.Hyb,Data.MomFlux.Hyb);
  a = a(:,  zidx,:,:,:);
  a = a(:,:,lonidx,:,:);
  a = a(:,:,:,latidx,:);
  a = squeeze(nanmean(a,[2:4]));
  HeatFlux.Obs = a(:,1); HeatFlux.ReA = a(:,2); HeatFlux.Hyb = a(:,5); 
  MomFlux.Obs  = a(:,3); MomFlux.ReA  = a(:,4); MomFlux.Hyb  = a(:,6); 
  clear zidx latidx lonidx a
  
  
  
  
  Vars = {'Obs','ReA','Hyb'};
  for iVar=1:1:numel(Vars)
  
    %remove outliers
    %this affects 2 bad days in Aeolus pre-SSW in momentum flux
    [~,rm] = rmoutliers(MomFlux.(Vars{iVar})); 
    a = MomFlux.(Vars{iVar}); a(rm) = NaN; MomFlux.(Vars{iVar}) = a;    
    
    %smooth?
    HeatFlux.(Vars{iVar}) = smoothn(inpaint_nans(HeatFlux.(Vars{iVar})),[Settings.SmoothDays]);
    MomFlux.( Vars{iVar}) = smoothn(inpaint_nans( MomFlux.(Vars{iVar})),[Settings.SmoothDays]);

    %normalise?
    if Settings.Normalise == 1;
      
      %retain original range
      HeatFlux.Range.(Vars{iVar}) = minmax(HeatFlux.(Vars{iVar}));
      MomFlux.Range.( Vars{iVar}) = minmax(MomFlux.( Vars{iVar}));
      
      %normalise
      HeatFlux.(Vars{iVar}) = (HeatFlux.(Vars{iVar}) - nanmean(HeatFlux.(Vars{iVar})))./nanstd(HeatFlux.(Vars{iVar}));
      MomFlux.( Vars{iVar}) = (MomFlux.( Vars{iVar}) - nanmean(MomFlux.( Vars{iVar})))./nanstd(MomFlux.( Vars{iVar}));
      
    end
  end; clear iVar

  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% repeat for climatology
  %outlier removal omitted, as ERA5 data is 'clean' relative to obs
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
  
  Clima = load('wave_clima/merged_ssw_clima.mat');
  
  %shift times
  t = Clima.Store.Grid.TimeScale;
  for iSSW=1:1:numel(Clima.Store.SSWs)
    t(:,:,:,:,iSSW) = t(:,:,:,:,iSSW)-Clima.Store.SSWs(iSSW);
  end; clear iSSW
  t = squeeze(t);
  
  %find region
  zidx   = closest(Clima.Store.Grid.HeightScale,Settings.Levels(iLevel));
  latidx = inrange(Clima.Store.Grid.LatScale,   Settings.LatRange);
  lonidx = inrange(Clima.Store.Grid.LonScale,   Settings.LonRange);
  
  a = Clima.Store.HeatFlux.ReA;
  a = a(:,  zidx,:,:,:,:);
  a = a(:,:,lonidx,:,:,:);
  a = a(:,:,:,latidx,:,:);
  a = squeeze(nanmean(a,[2:4]));
  Clima.Store.HeatFlux.ReA = a;
  
  a = Clima.Store.MomFlux.ReA;
  a = a(:,  zidx,:,:,:,:);
  a = a(:,:,lonidx,:,:,:);
  a = a(:,:,:,latidx,:,:);
  a = squeeze(nanmean(a,[2:4]));
  Clima.Store.MomFlux.ReA = a; 
  clear a zidx lonidx latidx
  
  %smooth?
  Clima.Store.HeatFlux.ReA = smoothn(inpaint_nans(Clima.Store.HeatFlux.ReA),[Settings.SmoothDays,1]);
  Clima.Store.MomFlux.ReA  = smoothn(inpaint_nans(Clima.Store.MomFlux.ReA ),[Settings.SmoothDays,1]);
  
  %normalise?
  if Settings.Normalise == 1;
        
    %normalise
    Clima.Store.HeatFlux.ReA  = (Clima.Store.HeatFlux.ReA  - nanmean(Clima.Store.HeatFlux.ReA))./nanstd(Clima.Store.HeatFlux.ReA);
    Clima.Store.MomFlux.ReA   = (Clima.Store.MomFlux.ReA   - nanmean(Clima.Store.MomFlux.ReA ))./nanstd(Clima.Store.MomFlux.ReA );
    
  end

  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% plot
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  

  
  
  %heat flux
  %%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  k = k+1;l = l+1;
  subplot(numel(Settings.Levels),5,[k,k+1])
  hold on;box on; grid on; ylim([-1,1].*3)

  %plot climatology
  for iSSW=1:1:numel(Clima.Store.SSWs)
    plot(t(:,iSSW),Clima.Store.HeatFlux.ReA(:,iSSW),'color',[1,1,1].*0.6,'linewi',0.5)
  end
  
  %plot data
  plot(Data.Grid.TimeScale,HeatFlux.ReA,'-','linewi',2,'color',Colours.ReA)
  plot(Data.Grid.TimeScale,HeatFlux.Obs,'-','linewi',2,'color',Colours.Obs)
  plot(Data.Grid.TimeScale,HeatFlux.Hyb,'-','linewi',2,'color',Colours.Hyb)
  xlim([datenum(2020,[10,15],1)]-datenum(2021,1,5))    
  if iLevel ~= numel(Settings.Levels);  set(gca,'xtick',-100:20:100,'xticklabel',[]);
  else;                                 set(gca,'xtick',-100:20:100,'xticklabel',-100:20:100); xlabel('Days since SSW');
  end
  
  
  Good = find(~isnan(HeatFlux.Obs+HeatFlux.ReA+HeatFlux.Hyb));
  r1 = corrcoef(HeatFlux.Obs(Good),HeatFlux.ReA(Good)); r1 = r1(2);
  r2 = corrcoef(HeatFlux.Hyb(Good),HeatFlux.ReA(Good)); r2 = r2(2);
  
  if Settings.Normalise == 1; ylabel('Z-Score'); ylim([-1,1].*4); end
  xLimits = get(gca,'XLim');yLimits = get(gca,'YLim');
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.83.*range(yLimits),['r_{obs}=',sprintf('%1.2f',r1)],'horizontalalignment','right','fontsize',10)
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.90.*range(yLimits),['r_{hyb}=',sprintf('%1.2f',r2)],'horizontalalignment','right','fontsize',10)
  text(min(xLimits)+0.02.*range(xLimits),min(yLimits)+0.92.*range(yLimits),['(',Letters(l),') ',num2str(h2p(Settings.Levels(iLevel))),'hPa'],'horizontalalignment','left','fontsize',15)
  text(min(xLimits)+0.02.*range(xLimits),min(yLimits)+0.05.*range(yLimits),['45N - ',num2str(Settings.LatRange(2)),'N'],'horizontalalignment','left','fontsize',12)
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.05.*range(yLimits),['Smoothed ',num2str(Settings.SmoothDays),' days'],'horizontalalignment','right','fontsize',12)
  if iLevel == 1; title(['Eddy Heat Flux    v''T''']); end
  plot([0,0],yLimits,'linewi',2,'color','k')
  drawnow
  
  
  
  
  
  
  %momentum flux
  %%%%%%%%%%%%%%%%%%%%%%%%%%%  
  
  
  k = k+2;l = l+1;
  subplot(numel(Settings.Levels),5,[k,k+1])
  hold on;box on; grid on; ylim([-1,1].*2)
  
  %plot climatology
  for iSSW=1:1:numel(Clima.Store.SSWs)
    plot(t(:,iSSW),Clima.Store.MomFlux.ReA(:,iSSW),'color',[1,1,1].*0.6,'linewi',0.5)
  end  
  
  %plot real data
  plot(Data.Grid.TimeScale,MomFlux.ReA,'-','linewi',2,'color',Colours.ReA)
  plot(Data.Grid.TimeScale,MomFlux.Obs,'-','linewi',2,'color',Colours.Obs)
  plot(Data.Grid.TimeScale,MomFlux.Hyb,'-','linewi',2,'color',Colours.Hyb)
  xlim([datenum(2020,[10,15],1)] -datenum(2021,1,5))  
  if iLevel ~= numel(Settings.Levels);  set(gca,'xtick',-100:20:100,'xticklabel',[]);
  else;                                 set(gca,'xtick',-100:20:100,'xticklabel',-100:20:100); xlabel('Days since SSW');
  end
  plot([0,0],yLimits,'linewi',2,'color','k')

  Good = find(~isnan(MomFlux.Obs+MomFlux.ReA+MomFlux.Hyb));
  r1 = corrcoef(MomFlux.Obs(Good),MomFlux.ReA(Good)); r1 = r1(2);
  r2 = corrcoef(MomFlux.Hyb(Good),MomFlux.ReA(Good)); r2 = r2(2);
  
  xLimits = get(gca,'XLim');yLimits = get(gca,'YLim');
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.83.*range(yLimits),['r_{obs}=',sprintf('%1.2f',r1)],'horizontalalignment','right','fontsize',10)
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.90.*range(yLimits),['r_{hyb}=',sprintf('%1.2f',r2)],'horizontalalignment','right','fontsize',10)
  text(min(xLimits)+0.02.*range(xLimits),min(yLimits)+0.92.*range(yLimits),['(',Letters(l),') ',num2str(h2p(Settings.Levels(iLevel))),'hPa'],'horizontalalignment','left','fontsize',15)
  text(min(xLimits)+0.02.*range(xLimits),min(yLimits)+0.05.*range(yLimits),['45N - ',num2str(Settings.LatRange(2)),'N'],'horizontalalignment','left','fontsize',12)
  text(min(xLimits)+0.99.*range(xLimits),min(yLimits)+0.05.*range(yLimits),['Smoothed ',num2str(Settings.SmoothDays),' days'],'horizontalalignment','right','fontsize',12)
  
  if iLevel == 1; title(['Eddy Momentum Flux    u''v''']); end

  

  drawnow
  
  
  
  
  
  %unscaled data
  %%%%%%%%%%%%%%%%%%%%%%%%%%%  
  
  
  %plot range of unnormalised data
  k = k+2;
  if Settings.Normalise == 1;
    
    subplot(numel(Settings.Levels),5,k)
    hold on
    plot([1,1].*1,HeatFlux.Range.ReA,'o-','linewi',2,'color',Colours.ReA)
    plot([1,1].*2,HeatFlux.Range.Hyb,'o-','linewi',2,'color',Colours.Hyb)
    plot([1,1].*3,HeatFlux.Range.Obs,'o-','linewi',2,'color',Colours.Obs)
    plot([1,1].*5, MomFlux.Range.ReA,'^-','linewi',2,'color',Colours.ReA)
    plot([1,1].*6, MomFlux.Range.Hyb,'^-','linewi',2,'color',Colours.Hyb)
    plot([1,1].*7, MomFlux.Range.Obs,'^-','linewi',2,'color',Colours.Obs)
 
    set(gca,'yaxislocation','right')
    if iLevel == numel(Settings.Levels);  
      set(gca,'xtick',1:1:7,'xticklabel',{'ReA','Hyb','Obs',' ','ReA','Hyb','Obs'})
      xtickangle(90)
    else
      set(gca,'xtick',1:1:7,'xticklabel',[])
    end
    
    xlim([0.5 7.5])
    yLimits = get(gca,'YLim'); ylim([-1,1].*max(abs(yLimits)));yLimits = get(gca,'YLim'); 
    plot([1,1].*4,yLimits,'k:','linewi',3);
    box on
    if iLevel == 1; 
      text(2.5,max(yLimits).*1.15,'v''T''','horizontalalignment','center')
      text(5.5,max(yLimits).*1.15,'u''v''','horizontalalignment','center')
    end
    ylabel('Raw Value')
    l = l+1;text(0.55,-max(yLimits).*0.9,['(',Letters(l),') '])
    
  end

    

  
  
  
end
