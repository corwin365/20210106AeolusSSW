clearvars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%produce an MLS T climatology
%use same gridding as the main plot, to simplify logic in plotting routine
%
%
%Corwin Wright, c.wright@bath.ac.uk, 2021/01/24
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%general
Settings.OutFile          = 'zm_data_mls_clim.mat';

%regionalisation
Settings.LatRange         = [60,90];
Settings.Grid.TimeScale   = date2doy(datenum(2020,10,1):1:datenum(2021,2,28)); 
Settings.Grid.TimeScale(Settings.Grid.TimeScale > 180) = Settings.Grid.TimeScale(Settings.Grid.TimeScale > 180)-366; %2020 has 366 days
Settings.Grid.HeightScale = [10:4:50,54:6:120]; %km


%years to use
%average for each DoY will be taken at end
Settings.Grid.Years       = 2005:1:2021;

%list of datasets
Settings.DataSets         = {'Mls'};

%MLS-specific settings
Settings.Mls.DataDir      = [LocalDataDir,'/MLS/'];
Settings.Mls.InVars       = {'T','O3','CO','U','V'};
Settings.Mls.OutVars      = {'T','O3','CO','U','V'};


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% create storage grids
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%make a list of unique dataset-var combinations
Results.VarList  = {};
Results.InstList = {};
for iDataSet=1:1:numel(Settings.DataSets)
  VarList = Settings.(Settings.DataSets{iDataSet}).OutVars;
  for iVar=1:1:numel(VarList)
    Results.InstList{end+1} = Settings.DataSets{iDataSet};
    Results.VarList{ end+1} = VarList{iVar};
  end
end; clear iDataSet iVar VarList

Results.Data = NaN(numel(Results.VarList),           ...
                   numel(Settings.Grid.TimeScale),   ...
                   numel(Settings.Grid.HeightScale), ...
                   numel(Settings.Grid.Years));           %last dim will be averaged over before saving
                 
Results.Grid = Settings.Grid; %so we can just load the "results" struct in later scripts

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% grid data!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%fastest to loop over datasets first and then date, as files are likely to
%be sequential on the disk.

for iDataSet=1:1:numel(Settings.DataSets)
  
  textprogressbar(['Processing ',Settings.DataSets{iDataSet},' '])
  for iDay=1:1:numel(Settings.Grid.TimeScale)
    
    for iYear=1:1:numel(Settings.Grid.Years)
      
      Day = datenum(Settings.Grid.Years(iYear),1,1)+Settings.Grid.TimeScale(iDay);
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %load data and format into a common format we can grid later
      %these functions will return a single list of points for each
      %variable, with associated geolocation
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      switch Settings.DataSets{iDataSet}
        case 'Mls';    Data = get_mls(Day, ...
                                      Settings.Mls.DataDir,          ...
                                      Settings.Mls.InVars,           ...
                                      Settings.Mls.OutVars);
        otherwise; disp('Dataset not in valid list. Stopping'); stop;
      end
      clear Day
      if numel(Data.Lat) == 0; continue; end %no data
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %grid the data
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      VarList = Settings.(Settings.DataSets{iDataSet}).OutVars;
      for iVar=1:1:numel(VarList)
        
        %load variable
        if ~isfield(Data,VarList{iVar});continue; end
        Var = Data.(VarList{iVar});
        if numel(Var) == 0; continue; end
        
        %bin variable
        InRange = inrange(Data.Lat,Settings.LatRange);
        zz = bin2matN(1,Data.Alt(InRange),Var(InRange),Settings.Grid.HeightScale);
        
        %store it
        ThisVar = find(contains(Results.InstList,Settings.DataSets{iDataSet}) ...
                     & contains( Results.VarList,VarList{iVar}));
        Results.Data(ThisVar,iDay,:,iYear) = zz;
        
        %and we're done
      end; clear iVar VarList zz Var ThisVar Data InRange

    end
    textprogressbar(iDay./numel(Settings.Grid.TimeScale).*100)
  end; clear iDay
  textprogressbar('!')
end; clear iDataSet
clear xi yi zi


%take mean over years
Results.Data = nanmedian(Results.Data,4);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

save(Settings.OutFile,'Results','Settings')