clearvars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%plot time series of zonal mean MLS T
%
%Corwin Wright, c.wright@bath.ac.uk, 2021/01/18
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Settings.Var         = 'T';
Settings.HeightRange = [0,90]; %km
Settings.TimeRange   = [-62,61]; %DoY relative to 01/Jan

%smooth?
Settings.SmoothSize = [9,1]; %time units, height units - both depend on gridding choices

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Data = load('mls_data.mat');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% split into winters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%start by splitting into calendar years
[y,~,~] = datevec(Data.Settings.TimeScale);
Years = unique(y);
Days = NaN(numel(Years),366); Indices = Days;
for iYear=1:1:numel(Years)
  ThisYear = find(y == Years(iYear));
  Days(   iYear,1:numel(ThisYear)) = date2doy(Data.Settings.TimeScale(ThisYear));
  Indices(iYear,1:numel(ThisYear)) = ThisYear;
end; clear iYear ThisYear y


%now, shift the DoYs so that DoYs > 180 are -ve
%we're most interested in 2021, so the leap year in 2020 matters, annoyingly
for iYear=1:1:numel(Years)
  dd = Days(iYear,:);
  DaysThisYear = datenum(Years(iYear)+1,1,1)-datenum(Years(iYear),1,1);
  dd(dd > 180) = dd(dd > 180)-DaysThisYear;
  Days(iYear,:) = dd;
end; clear dd iYear DaysThisYear

%finally, rearrange the data into winters...
Winters = NaN(numel(Years),366);
for iYear=2:1:numel(Years)
  PositiveDays = find(Days(iYear,:)   >  0);
  NegativeDays = find(Days(iYear-1,:) <= 0);
  
  %INDICES IN THE RAW DATA
  Winters(iYear,1:1:numel(NegativeDays)) = Indices(iYear-1,NegativeDays);
  Winters(iYear,numel(NegativeDays)+1:1:numel(NegativeDays)+numel(PositiveDays)) = Indices(iYear,PositiveDays);
  
end
clear iYear Indices Days PositiveDays NegativeDays

%... and drop empty years/doys
Years = Years(find(nansum(Winters,2) > 0));
Winters = Winters(find(nansum(Winters,2) > 0),:);
Winters = Winters(:,find(nansum(Winters,1) > 0));

%we now have an array Years containing the year numbers
%and an array winters with the original-data indices for all days in the
%dataset from -180 to +186 in this winter
%that was fiddlier than expected.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot the winters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

set(gcf,'color','w')
clf
% subplot = @(m,n,p) subtightplot (m, n, p, [0.07,0.05],  0.10,0.15);
subplot = @(m,n,p) subtightplot (m, n, p, [0.07,0.05],  0.15,0.15);

for iYear=1:1:numel(Years)
  
  %create plot
  subplot(numel(Years),1,iYear)
  axis([Settings.TimeRange Settings.HeightRange])
  hold on; box on
  ylabel(Years(iYear),'fontsize',24)
  set(gca,'ytick',0:10:150); ylabel('Altitude [km]') %altitude  
  set(gca,'tickdir','out')
  
  %get indices for this year
  ThisYear = Winters(iYear,:); ThisYear = ThisYear(~isnan(ThisYear)); %DAY INDICES
  
  %pull out DATA for the year
  Var = Data.Results.(Settings.Var);
  Var = Var(ThisYear,:,:);
  
  %reshape to include subdaily data
  Var = reshape(permute(Var,[2,1,3]),size(Var,1)*size(Var,2),size(Var,3));

  %produce a time axis
  [dd,hh] = meshgrid(Data.Settings.TimeScale(ThisYear),Data.Settings.HourScale(1:end-1)./24);
  t = dd(:)+hh(:);
  t = t-datenum(Years(iYear),1,1);
  
  %smooth?
  if nanmean(Settings.SmoothSize) ~= 1;
    Bad = find(isnan(Var));
    Var = smoothn(inpaint_nans(Var),Settings.SmoothSize); 
    Var(Bad) = NaN; clear Bad
  end
  
% %   %subtract time-mean at each height
% %   Var = Var - repmat(nanmean(Var,1),size(t,1),1);
% %   
  
  
  %overinteprolate, so that the steps up are rectangles rather than triangles
  t2 = t;%min(t):0.1:max(t);
  Var2 = interp1(t,Var,t2,'nearest');
%   Bad = find(isnan(Var2));
%   Var2 = smoothn(inpaint_nans(Var2),[17,1]); %this smoothing is smaller than the overinterpolation, so it just makes the data look less jagged without altering the measured signal
%   Var2(Bad) = NaN;
  
  %fill bottom contourf
  Var2(Var2 < -5) = -5;
  
  %plot coloured contours
  contourf(t2,Data.Settings.HeightScale,Var2',200:5:260,'edgecolor','none');
  shading flat;     hold on
  
  %add line contours
  [c,h] = contour(t2,Data.Settings.HeightScale,Var2',-10:1:10,'edgecolor',[1,1,1].*0.4);
  clabel(c,h);
  
  %tidy up
  colormap(flipud(cbrewer('div','RdYlBu',numel(-5:0.5:5))))
%   caxis([-1,1].*5)
  caxis([200 260])
  xlabel(['Day of ',num2str(Years(iYear))]);

  
% %   %master plot labelling
% %   if iYear == 1;
% %     text(min(Settings.TimeRange)+0.01.*range(Settings.TimeRange), ...
% %          1.1.*range(Settings.HeightRange)-min(Settings.HeightRange), ...
% %          '\it{Data: @ESA\_Aeolus         Analysis: @CorwinWright + @TPBanyard, @UniofBath}', ...
% %          'fontsize',10,'color',[1,1,1].*0.3)
% %   end
  text(min(Settings.TimeRange)+0.01.*range(Settings.TimeRange), ...
       0.05.*range(Settings.HeightRange)-min(Settings.HeightRange), ...
       [num2str(Years(iYear)-1),'/',num2str(Years(iYear)-2000),', ',num2str(min(Data.Settings.LatRange)),'N-',num2str(max(Data.Settings.LatRange)),'N mean' ], ...
       'fontsize',18,'verticalalignment','top')
  
  %SSW peak indicators
  if Years(iYear) == 2021
    plot(5,7,'^','color','k','markerfacecolor','k','markersize',10)
    plot([5,5],[2,7],'k-','linewi',5,'clipping','off')
    text(6,5,'SSW')
  end

  
  if iYear == 1; set(gca,'xaxislocation','top'); end
    
  %month labelling
%   if iYear < numel(Years)
    yLimits = get(gca,'YLim');
    MonthPoints = [-61,-31,0,31,59];
    Names = {'Nov','Dec','Jan','Feb'};
    for iMonth=2:1:numel(MonthPoints)
      plot(MonthPoints([iMonth-1,iMonth])+[1,-1], ...
        min(yLimits)-0.08.*range(yLimits).*[1,1], ...
        'k-','clipping','off')
      plot(MonthPoints([iMonth-1,iMonth])+[1,-1].*11, ...
        min(yLimits)-0.08.*range(yLimits).*[1,1], ...
        'w-','clipping','off')
      plot(MonthPoints(iMonth-1),min(yLimits)-0.08.*range(yLimits),'ks','markerfacecolor','k','clipping','off','markersize',10)
      plot(MonthPoints(iMonth  ),min(yLimits)-0.08.*range(yLimits),'ks','markerfacecolor','k','clipping','off','markersize',10)
      text(mean(MonthPoints([iMonth-1,iMonth])), ...
        min(yLimits)-0.08.*range(yLimits),Names{iMonth-1}, ...
        'horizontalalignment','center')
    end
%   end
  ylim(yLimits)
  
  %overlay tropopause height
  TP = load('../06TropopauseFinding/tropopause_60N.mat');
  TP.Time = TP.Time-datenum(Years(iYear),1,1);
  plot(TP.Time,TP.Height,'k-','linewi',2)
  clear TP


     
  %second vertical axss. done last as it affects the above
  ax1 = gca;
  ax2 = axes('Position',ax1.Position,...
             'XAxisLocation','top',...
             'YAxisLocation','right',...
             'Color','none');
  set(gca,'xtick',[],'tickdir','out')
  set(gca,'ytick',0:10:150,'yticklabel',roundsd(h2p(0:10:150),2))
  ylim(Settings.HeightRange)
  ylabel('Pressure [hPa]')
  

  drawnow
  
  
  
end

%%
%colourbar
 colormap(flipud(cbrewer('div','RdYlBu',numel(-5:0.5:5)-1)))
cb =colorbar('position',[0.05 0.33 0.02 0.33]);
caxis([-1,1].*5);
cb.Label.String = ['\Delta T from period mean [K]'];
