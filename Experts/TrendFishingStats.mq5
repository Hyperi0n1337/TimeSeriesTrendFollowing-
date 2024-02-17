#include <Candle.mqh>
#include <CandlePattern.mqh>
#include <MARibbon.mqh>
#include <SeriesUtil.mqh>
#include <TimeframeUtil.mqh>
#include <Trade/Trade.mqh>
#include <SR.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Consolidation.mqh>
#include <Object.mqh>

/*
   Statistics to find:
   
   - Series of trend info:
      * Timestamp (since epoch) of starting candle
      * Timestamp of ending candle
      * Trend length in candles
      * Trend type: bullish or bearish
      * Retracements per trend
      * Total small fish crosses (cross over but not true retracement)
      
   
   
   Definition of a trend start:
   - Big fish MA turns trendy from crossed
   
   Definition of a trend end:
   - Big fish MA crosses from trendy
   
   Definition of retracement:
   - Smallest fish temperarily crossed
   - Candles after retracement must make new high/low than previous

*/


/*
   Inputs
*/

//Small fish period
input int small_fish_period_1 = 3; // Small fish 1 (smallsest small fish) period
input int small_fish_period_2 = 5; // Small fish 2 period
input int small_fish_period_3 = 8; // Small fish 3 period
input int small_fish_period_4 = 10; // Small fish 4 period
input int small_fish_period_5 = 12; // Small fish 5 period
input int small_fish_period_6 = 15; // Small fish 6 (biggest small fish) period

//big fish period
input int big_fish_period_1 = 30; // Big fish 1 (smallsest big fish) period
input int big_fish_period_2 = 35; // Big fish 2 period
input int big_fish_period_3 = 40; // Big fish 3 period
input int big_fish_period_4 = 45; // Big fish 4 period
input int big_fish_period_5 = 50; // Big fish 5 period
input int big_fish_period_6 = 60; // Big fish 6 (biggest big fish) period


class TrendInfo: public CObject {
public:
   ENUM_RIBBON_TREND trend_type;
   datetime start_time;
   datetime stop_time;
   
   unsigned int candle_count;
   unsigned int retracement_count;
   unsigned int small_fish_cross_count;
};


/*
   Globals
*/
CArrayObj trend_info_list;

MARibbon big_fish(6, _Symbol);
MARibbon small_fish(6, _Symbol);

ENUM_RIBBON_TREND curr_running_trend;
int curr_trend_candle_count = 0;
int curr_small_fish_cross_count = 0;
int curr_retracement_count = 0;

datetime curr_trend_begin_time;

int OnInit()
{
   big_fish.SetTimeFrame(_Period);
   small_fish.SetTimeFrame(_Period);
   
   small_fish.SetPeriod(0, small_fish_period_1);
   small_fish.SetPeriod(1, small_fish_period_2);
   small_fish.SetPeriod(2, small_fish_period_3);
   small_fish.SetPeriod(3, small_fish_period_4);
   small_fish.SetPeriod(4, small_fish_period_5);
   small_fish.SetPeriod(5, small_fish_period_6);
   
   big_fish.SetPeriod(0, big_fish_period_1);
   big_fish.SetPeriod(1, big_fish_period_2);
   big_fish.SetPeriod(2, big_fish_period_3);
   big_fish.SetPeriod(3, big_fish_period_4);
   big_fish.SetPeriod(4, big_fish_period_5);
   big_fish.SetPeriod(5, big_fish_period_6);
   
   
   Print("Init end");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   //FormReport();
   Print("Deinit");
}

void OnTick()
{

   static bool first_iteration = true;
   static bool skip_to_next_trend = false;
   static bool in_trend_flag = false;
   static bool small_fish_crossed_flag = false;
   
   static double prev_trend_high = 0.0;
   static double curr_trend_high = 0.0;
   
   if(first_iteration) {
      //reserved in case of future first iteration set up
      if(big_fish.IsCurrDownTrend() || big_fish.IsCurrUpTrend()) {
         //already in a trend, skip it to count full trends
         skip_to_next_trend = true;
         Print("Trend skip mode");
      }
      first_iteration = false;
   }
   
   if(!TimeframeUtil::IsCurrPeriodNewTimeframe()) {
      return;
   }
  
   /*
   
     Runs at the first tick of a new time frame (candle))
      
   */
   
   if(in_trend_flag) {
   
      //update the high of each trend, high as in the maxinum ask this trend acheived in its perspective direction
      //larger exchange rate in bullish trend, smaller in bearish
      Candle last_candle;
      CandleUtil::FormLatestCandle(last_candle, _Symbol, _Period);
      curr_trend_high = curr_running_trend == RT_UP ? MathMax(curr_trend_high, MathMax(last_candle.open, last_candle.close)) : MathMin(curr_trend_high, MathMin(last_candle.open, last_candle.close));
      ObjectMove(0, "curr_trend_high", 0, 0, curr_trend_high);  
   }
   
   ENUM_RIBBON_TREND trend;
   
   if(big_fish.IsCurrDownTrend()) {
      trend = RT_DOWN;      
   } else if(big_fish.IsCurrUpTrend()) {
      trend = RT_UP;
   } else {
   
      if(skip_to_next_trend) {
         skip_to_next_trend = false;
         return;
      }
      
      if(in_trend_flag) {
         //trend ended
         
         TrendInfo *info = new TrendInfo();
         info.trend_type = curr_running_trend;
         info.start_time = curr_trend_begin_time;
         info.stop_time = TimeCurrent();
         info.candle_count = curr_trend_candle_count;
         info.retracement_count = curr_retracement_count;
         info.small_fish_cross_count = curr_small_fish_cross_count;
         
         trend_info_list.Add(info);
          
         PrintFormat("Trend ended. Candle count:%d, type:%d, small fish croses:%d, retracements:%d", curr_trend_candle_count, curr_running_trend, curr_small_fish_cross_count, curr_retracement_count);
         curr_trend_candle_count = 0;
         curr_small_fish_cross_count = 0;
         curr_retracement_count = 0;
         
         if(ObjectFind(0, "prev_trend_high") >= 0) {
            ObjectDelete(0, "prev_trend_high");
         }
         
         ObjectDelete(0, "curr_trend_high");
         
         curr_trend_high = 0.0;
         prev_trend_high = 0.0;
         
         in_trend_flag = false;
      }
      return;
   }  
   
   if(skip_to_next_trend) {
      return;
   }
  
   if(!in_trend_flag) {
      //beginning of new trend
      Print("New trend:", trend);
      curr_running_trend = trend;
      
      curr_trend_begin_time = TimeCurrent();
      
      ObjectCreate(0, "curr_trend_high", OBJ_HLINE, 0, 0, 0.0);
      ObjectSetInteger(0, "curr_trend_high", OBJPROP_COLOR, clrWhite);
      
      if(curr_running_trend == RT_DOWN) {
         curr_trend_high = DBL_MAX;
      }
      
      in_trend_flag = true;
      small_fish_crossed_flag = false;
   }
   
   if(!small_fish.IsCurrDownTrend() && !small_fish.IsCurrUpTrend() && !small_fish_crossed_flag) {
      //small fish cross where previously it was trendy
      
      if(curr_trend_high > prev_trend_high) {
      
         if(curr_small_fish_cross_count > 0) {
            curr_retracement_count++;
         }
         
         prev_trend_high = curr_trend_high;
         
         if(ObjectFind(0, "prev_trend_high") < 0) {
            ObjectCreate(0, "prev_trend_high", OBJ_HLINE, 0, 0, prev_trend_high);
            ObjectSetInteger(0, "prev_trend_high", OBJPROP_COLOR, clrGreen);    
         } else {
            ObjectMove(0, "prev_trend_high", 0, 0, prev_trend_high);
         }
      
      }
      small_fish_crossed_flag = true;   
   }
   
   if( ( (trend == RT_UP && small_fish.IsCurrUpTrend()) || (trend == RT_DOWN && small_fish.IsCurrDownTrend()) ) && small_fish_crossed_flag ) {
      //small fish returned to trendy from crossed condition
      
      curr_small_fish_cross_count++;
      
      Candle last_candle;
      CandleUtil::FormLatestCandle(last_candle, _Symbol, _Period);
      curr_trend_high = MathMax(last_candle.open, last_candle.close);
      ObjectMove(0, "curr_trend_high", 0, 0, curr_trend_high);
      small_fish_crossed_flag = false;
   }
   
   curr_trend_candle_count++;
   Comment("In trend flag: " , in_trend_flag , "\nSmall fish cross flag: ", small_fish_crossed_flag, "\nPrev trend high: ", prev_trend_high, "\nCurr trend high: ", curr_trend_high);
   
}

void FormReport() {
   Print("Generating repots...");
   
   FormTrendInfoCSV();
}

void FormTrendInfoCSV() {
   int fd = FileOpen("TrendStats.csv", FILE_WRITE | FILE_CSV); //actually going to be tab delimited by default
   if(fd < 0) {
      Print("Err creating file: ", GetLastError());
      return;
   }
   
   //write headings
   FileWrite(fd, "start_time", "stop_time", "candle_count", "type", "retracement_count", "small_fish_cross_count");
   
   //write data
   TrendInfo *info_ptr;
   for(int i = 0; i < trend_info_list.Total(); ++i) {
      info_ptr = (TrendInfo*) trend_info_list.At(i);
      FileWrite(fd, (long) info_ptr.start_time, (long) info_ptr.stop_time, info_ptr.candle_count, info_ptr.trend_type, info_ptr.retracement_count, info_ptr.small_fish_cross_count);
   }
   
   FileClose(fd);
}