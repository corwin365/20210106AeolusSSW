clear all

SSWDates = [datenum(2006,1,21), ...
            datenum(2007,2,24), ...
            datenum(2008,2,22), ...
            datenum(2009,1,24), ...
            datenum(2010,2,09), ...
            datenum(2010,3,24), ...
            datenum(2013,1,06), ...
            datenum(2018,2,12), ...
            datenum(2019,1,02)];
          
for iSSW=1:1:numel(SSWDates)
  CENTREDAY = SSWDates(iSSW);
  grid_datasets;
  compute_fluxes;
end

merge_lines