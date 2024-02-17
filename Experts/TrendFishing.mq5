//+------------------------------------------------------------------+
//|                                                 TrendFishing.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQe Corp."
#property link      "https://www.mq"
#property version   "1.00"

#include <Candle.mqh>
#include <CandlePattern.mqh>
#include <MARibbon.mqh>
#include <SeriesUtil.mqh>
#include <TimeframeUtil.mqh>
#include <Trade/Trade.mqh>
#include <SR.mqh>
#include <Generic/ArrayList.mqh>
#include <Consolidation.mqh>

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

//misc configs

//input unsigned int big_fish_trend_window = 50;
input unsigned int big_fish_look_back_window = 6;  // Window to normalize current trend against
//input unsigned int small_fish_trend_window = 50;
//input unsigned int small_fish_look_back_window = 6;        // Time slots needed to satisfy trend strength
input unsigned int small_fish_valid_window = 2;    // Window to which a small fish entry is considered valid after the small fish trend collapsed


//input double sparse_threshold = 0.40;
//input double sparse_threshold_factor = 5.0;
//input double bunch_threshold = 0.10; 
input double parallel_threshold = 0.5;
input double max_small_fish_stab_threshold = 0.5;
input double max_candle_stab_threshold = 0.6;
//input double consolidation_slope_bound = 0.1;
//input double small_fish_expansion_threshold = 0.6;
input double sr_distance_percent = 0.15;
input bool double_down = true;

/*
   Globals
*/
MARibbon big_fish(6, _Symbol);
MARibbon small_fish(6, _Symbol);

bool first_iteration = true;

int curr_trend_begin_offset = -1;
double curr_trend_begin_gapsum = 0.0;

//int consolidation_ma_handle = -1;
double big_fish_gap_sum[];
double big_fish_gap_sum_diff[];
double normalized_big_fish_gap_sum_diff[];

int small_fish_recovery_count;

double entered_trend_peak = 0.0;
double entered_trend;

double trend_candles_max_range = 0.0;
double trend_candles_min_range = DBL_MAX;
double trend_candles_max_real_range = 0.0;
double trend_candles_min_real_range = DBL_MAX;

int sar_indicator = 0;

CTrade trade;
SR sr_manager;
ConsolidationContext cc;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
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
   
   //sr_manager.AddTimeframe(PERIOD_M30, clrRed);
   sr_manager.AddTimeframe(PERIOD_D1, clrCyan);
   
   sar_indicator = iSAR(_Symbol, _Period, 0.02, 0.2);
   
   Print("Init end");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinit");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(first_iteration) {
      
      //the minimum size is the lookback window size for big fish as we will have to look back that far to establish parallel
      ArrayResize(big_fish_gap_sum, big_fish_look_back_window);
      ArrayResize(big_fish_gap_sum_diff, big_fish_look_back_window - 1);
      ArrayResize(normalized_big_fish_gap_sum_diff, big_fish_look_back_window - 1);
      
      //start finding the reversal point
      curr_trend_begin_offset = big_fish.GetCurrTrendBeginningOffset();
      if(curr_trend_begin_offset > 0) {
         //curr_trend_begin_gapsum = big_fish.GetGapSum(curr_trend_begin_offset);
         //Print("beginning gapsum: ", curr_trend_begin_gapsum, " Offset: ", curr_trend_begin_offset);
         
         Candle candles[];
         ArrayResize(candles, curr_trend_begin_offset);
         CandleUtil::FormCandles(candles, _Symbol, _Period, curr_trend_begin_offset, 1);
         for(int i = 0; i < curr_trend_begin_offset; ++i) {
            MathMax(trend_candles_max_real_range, candles[i].BodyRange());
            MathMin(trend_candles_min_real_range, candles[i].BodyRange());
         }
      }
       
      first_iteration = false;
   }
   
   /*
      Update peaks of entered trend
   */
   
   if(entered_trend_peak != 0.0) {
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if( (entered_trend == RT_DOWN && bid < entered_trend_peak) || (entered_trend == RT_UP && bid > entered_trend_peak) ) {
         entered_trend_peak = bid;
         ObjectMove(0, "peak", 0, 0, bid);
      }
   }
   
  
   if(!TimeframeUtil::IsCurrPeriodNewTimeframe()) {
      return;
   }
  
   /*
   
      Below is ran at the first tick of a new time frame (candle))
      
   */
   
   sr_manager.Update();
   sr_manager.DrawSR();
   
   //make sure big fish is currently trending: no MA crossing over
   ENUM_RIBBON_TREND curr_trend;
   
   if(big_fish.IsCurrDownTrend()) {
      curr_trend = RT_DOWN;      
   } else if(big_fish.IsCurrUpTrend()) {
      curr_trend = RT_UP;
   } else {
      if(curr_trend_begin_offset > 0) {
         curr_trend_begin_offset = -1;
         
         trend_candles_max_real_range = 0.0;
         trend_candles_min_real_range = DBL_MAX;
         
         cc.Clear();
      }
      
      Print("No trend");
      return;
   }  
   
   //we are trending now. if we werent trending before set the the most recent offset as the beginning of a trend
   if(curr_trend_begin_offset < 0) {
      curr_trend_begin_offset = 1;
      curr_trend_begin_gapsum = big_fish.GetGapSum(1);
      
      Candle candle;
      CandleUtil::FormLatestCandle(candle, _Symbol, _Period);
      trend_candles_max_real_range = candle.BodyRange();
      trend_candles_min_real_range = candle.BodyRange();
   }
  
   static Candle pattern_candles[4];
   CandleUtil::FormCandles(pattern_candles, _Symbol, _Period, 4, 1);
   
   cc.AddNewWindow(pattern_candles, 4);
   cc.Draw();
   
   //double curr_candle_range = pattern_candles[0].BodyRange();
   //trend_candles_max_real_range = MathMax(trend_candles_max_real_range, pattern_candles[0].BodyRange());
   //trend_candles_min_real_range = MathMin(trend_candles_min_real_range, pattern_candles[0].BodyRange());
   
   //double body_size_ratio = pattern_candles[0].BodyRange() / trend_candles_max_real_range;
   //Print("Ratio: ", body_size_ratio);
  
   if(IsFishEntry(curr_trend) /*&& !BigFishStabCheck(curr_trend)*/) {
   
      if(!cc.IsConsolidation()) {
         BigShadowConfig bs_config;
         bs_config.use_coverage = false;
         
         KangarooConfig k_config;
         EngulfingConfig eg_config;
         
         if(curr_trend == RT_DOWN) {
            bs_config.setup_type = CPT_BEARISH;
            k_config.setup_type = CPT_BEARISH;
            eg_config.setup_type = CPT_BEARISH;
         } else {
            bs_config.setup_type = CPT_BULLISH;
            k_config.setup_type = CPT_BULLISH;
            eg_config.setup_type = CPT_BULLISH;
         }
         
         MqlDateTime curr_time;
         TimeCurrent(curr_time); 
      
         if(   CandlePattern::IsBigShadow(pattern_candles, 2, bs_config)) {
            printf("Bigshadow pattern condition at: %d/%d/%d\t%02d:%02d:%02d", curr_time.mon, curr_time.day, curr_time.year, curr_time.hour, curr_time.min, curr_time.sec);
            DrawArrow(curr_trend, true);
            OpenPosition(curr_trend);
         } else if(CandlePattern::IsKangarooTail(pattern_candles, 2, k_config) ) {
            printf("Kangaroo pattern condition at: %d/%d/%d\t%02d:%02d:%02d", curr_time.mon, curr_time.day, curr_time.year, curr_time.hour, curr_time.min, curr_time.sec);         
            DrawArrow(curr_trend, true);
            OpenPosition(curr_trend);
         } else if(CandlePattern::IsEngulfing(pattern_candles, 2,eg_config)){
            printf("Engulfing pattern condition at: %d/%d/%d\t%02d:%02d:%02d", curr_time.mon, curr_time.day, curr_time.year, curr_time.hour, curr_time.min, curr_time.sec);         
            DrawArrow(curr_trend, true);
            OpenPosition(curr_trend);
         } else {
            Print("No candle pattern");
            DrawArrow(curr_trend, false);
         }
      } else {
         Print("Consolidation");
      }
   }
      
   if(small_fish_recovery_count > 0) {
      small_fish_recovery_count--;
   }
   curr_trend_begin_offset++; 
   
   
   if(PositionsTotal() > 0) {
      AdjustPosition(curr_trend);
   }
}

void OnTrade() {
   if(PositionsTotal() == 0) {
      Print("All positions closed");
      entered_trend_peak = 0.0;
      ObjectDelete(0, "peak");
   }
}

bool IsFishEntry(const ENUM_RIBBON_TREND curr_trend) {
   
   //expand the arrays as necessary but never shrinking back to save allocation frequency
   if(ArraySize(big_fish_gap_sum) < curr_trend_begin_offset) {
      ArrayResize(big_fish_gap_sum, curr_trend_begin_offset);
   }
   
   if(ArraySize(big_fish_gap_sum_diff) < curr_trend_begin_offset - 1) {
      ArrayResize(big_fish_gap_sum_diff, curr_trend_begin_offset - 1);
      ArrayResize(normalized_big_fish_gap_sum_diff, curr_trend_begin_offset - 1);
   }
 
   //big fish should be as sparse as the beginning of the new trend
   /*
   if(big_fish.GetGapSum(1) < curr_trend_begin_gapsum) {
      return false;
   }*/
   
   //big fish trend strength check (make sure it's parallel or expanding)
   {
      unsigned int retreive_size = (curr_trend_begin_offset < (int) big_fish_look_back_window) ? big_fish_look_back_window : (unsigned int) curr_trend_begin_offset;
      
      big_fish.GetGapSums(big_fish_gap_sum, retreive_size, 1);
      SeriesUtil::GetSeriesDifference(big_fish_gap_sum_diff, big_fish_gap_sum, 0, retreive_size);
      SeriesUtil::NormalizeSeries(normalized_big_fish_gap_sum_diff, big_fish_gap_sum_diff);
      
      for(int i = ArraySize(normalized_big_fish_gap_sum_diff) - 1; i >= ArraySize(normalized_big_fish_gap_sum_diff) - ((int) big_fish_look_back_window - 1 ); --i) {
         if(normalized_big_fish_gap_sum_diff[i] < -parallel_threshold) {
            Print("Trend failed: Parallel: ", normalized_big_fish_gap_sum_diff[i]);
            return false;
         }
      }
   }
   
   //small fish cross over check
   {
      bool smallest_fish_crossed = ( curr_trend == RT_UP && !small_fish.IsCurrUpTrend() ) || ( curr_trend == RT_DOWN && !small_fish.IsCurrDownTrend() );
      
      if(smallest_fish_crossed) {
         small_fish_recovery_count = (int) small_fish_valid_window;
      }
      
      if(small_fish_recovery_count == 0) {
         Print("Trend failed: Small fish cross");
         return false;         
      }
   }
   
   //small fish cannot be inside big fish or beyond
   {
      double small_f_min, small_f_max;
      small_fish.GetMAMinMax(1, small_f_min, small_f_max);
      if(GetRibbonStabRatio(small_f_max, small_f_min, big_fish, curr_trend) > max_small_fish_stab_threshold) {
         Print("Trend failed: Small fish stab");
         return false;
      }
   }
   
   //price action stab
   {
         
      Candle candle;
      CandleUtil::FormLatestCandle(candle, _Symbol, _Period);
      
      if(GetRibbonStabRatio(MathMax(candle.open, candle.close), MathMin(candle.open, candle.close), big_fish, curr_trend) > max_candle_stab_threshold) {
         Print("Trend failed: price action stab");
         return false;
      }
   }
   
   return true;
}

double GetCandleStab(const Candle& candle, const MARibbon& ribbon, const ENUM_RIBBON_TREND curr_trend) {
   return GetRibbonStabRatio(candle.high, candle.low, ribbon, curr_trend);
}

double GetRibbonStabRatio(const double stabber_high, const double stabber_low, const MARibbon& stabbee, ENUM_RIBBON_TREND curr_trend) {
   double MAs_arr[];
   ArrayResize(MAs_arr, stabbee.GetMACount());
   
   stabbee.GetMA(MAs_arr, 1);
   
   double ribbon_high, ribbon_low;
   
   if(curr_trend == RT_UP) {
      //smallest fish above biggest fish in an uptrend
      ribbon_high = MAs_arr[0];
      ribbon_low = MAs_arr[stabbee.GetMACount() - 1];
      
      if(stabber_low <= ribbon_low) {
         return 1.0;
      } else if (stabber_low >= ribbon_high) {
         return 0.0;
      } else {
         return (ribbon_high - stabber_low) / (ribbon_high - ribbon_low);
      }
   } else {
      //smallest fish below biggest fish
      ribbon_high = MAs_arr[stabbee.GetMACount() - 1];
      ribbon_low = MAs_arr[0];
   
      if(stabber_high >= ribbon_high) {
         return 1.0;
      } else if (stabber_high <= ribbon_low) {
         return 0.0;
      } else {
         return (stabber_high - ribbon_low) / (ribbon_high - ribbon_low);
      }
   }
}

void DrawArrow(const ENUM_RIBBON_TREND trend, const bool candle_condition) {
   static unsigned int arrow_id = 0;
   
   string arrow_name = StringFormat("arrow%d", arrow_id);
   arrow_id++;
   
   ENUM_OBJECT arrow_type;
   
   MqlRates rate[1];
   CopyRates(_Symbol, _Period, 1, 1, rate);
   double price_point;
   
   if(trend == RT_UP) {
      price_point = rate[0].high + 0.001;
      arrow_type = OBJ_ARROW_DOWN;
   } else {
      price_point = rate[0].low - 0.0005;
      arrow_type = OBJ_ARROW_UP;
   }
   
   ObjectCreate(0, arrow_name, arrow_type, 0, rate[0].time, price_point);
   
   if(candle_condition) {
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrLime);
   }
}

void OpenPosition(const ENUM_RIBBON_TREND curr_trend) {

   if(double_down && PositionsTotal() > 0) {
      return;
   }

   double ma_arr[];
   ArrayResize(ma_arr, big_fish.GetMACount());
   
   big_fish.GetMA(ma_arr, 0);
   
   double stop_loss = ma_arr[big_fish.GetMACount() - 1];
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(curr_trend == RT_DOWN) {
      stop_loss += MathAbs(ask - ma_arr[big_fish.GetMACount() - 1]) * 0.20;
   } else {
      stop_loss -= MathAbs(ask - ma_arr[big_fish.GetMACount() - 1]) * 0.20;
   }
   
   double tp = 0.0;
   
   if(curr_trend == RT_DOWN) {
      
      tp = sr_manager.GetNextSupport(ask);
      if(tp != 0.0) {
         tp = tp + ( ( ask - tp ) * sr_distance_percent );
      }
      trade.Sell(1.0, _Symbol, 0.0, stop_loss, tp);   
   } else {
      
      tp = sr_manager.GetNextResistence(ask);
      if(tp != 0.0) {
         tp = tp - ( ( tp - ask ) * sr_distance_percent );
      }
      trade.Buy(1.0, _Symbol, 0.0, stop_loss, tp);
   }
   
   if(entered_trend_peak == 0.0) {
      
      entered_trend_peak = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ObjectCreate(0, "peak", OBJ_HLINE, 0, 0, entered_trend_peak);
      ObjectSetInteger(0, "peak", OBJPROP_COLOR, clrGreen);
      
      entered_trend = curr_trend;
   }
}

void AdjustPosition(const ENUM_RIBBON_TREND curr_trend) {

   static CArrayList<ulong> positions_to_close_list;

   double ma_arr[];
   ArrayResize(ma_arr, big_fish.GetMACount());
   
   big_fish.GetMA(ma_arr, 0);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double new_sl = ma_arr[big_fish.GetMACount() - 1];
   double new_tp = 0.0;
   
   //ulong ticket_buff;
   ulong pos_ticket;
   double old_sl , old_tp;
   double sar[1];
 
   //Print("=======================");
   for(int i = 0; i < PositionsTotal(); ++i) {
   
      pos_ticket = PositionGetTicket(i);
      //Print(pos_ticket);
      
      if(cc.IsConsolidation()) {
         trade.PositionClose(pos_ticket);
         continue;
      }
      
      CopyBuffer(sar_indicator, 0, 0, 1, sar);
      
      old_sl = PositionGetDouble(POSITION_SL);
      old_tp = PositionGetDouble(POSITION_TP);
      
      if(curr_trend == RT_DOWN) {
         
         //make sure sar is not currently at an up trend
         if(sar[0] < iHigh(_Symbol, _Period, 1)) {
            new_sl = MathMin(old_sl, new_sl);
         } else {
            new_sl = MathMin(old_sl, MathMin(new_sl, sar[0]));
         }
         
         
         new_tp = sr_manager.GetNextSupport(ask);
         if(new_tp > old_tp) {
            new_tp = new_tp + ( ( ask - new_tp ) * sr_distance_percent );
         } else {
            new_tp = old_tp;
         }
         
      } else if(curr_trend == RT_UP) {
      
         //make sure sar is not currently at a down trend
         if(sar[0] > iLow(_Symbol, _Period, 1)) {
            new_sl = MathMax(old_sl, new_sl);
         } else {
            new_sl = MathMax(old_sl, MathMax(new_sl, sar[0]));
         }
        
         new_tp = sr_manager.GetNextResistence(ask);
         if(new_tp < old_tp) {
            new_tp = new_tp - ( ( new_tp - ask ) * sr_distance_percent );
         } else {
            new_tp = old_tp;
         }
      }
      
      if(new_sl != old_sl || new_tp != old_tp) {
         trade.PositionModify(pos_ticket, new_sl, new_tp);
      }
   }
   
   
   if(positions_to_close_list.Count() > 0) {
      ulong ticket;
      for(int i = 0; i < positions_to_close_list.Count(); ++i) {
         positions_to_close_list.TryGetValue(i, ticket);
         trade.PositionClose(ticket);
      }
      
      positions_to_close_list.Clear();
   }
}

/*

* Relaxed entries? go in as soon as reversal happens? why wait for sparsness
* Why 30 - 60 days as big fish?
* if stabs 100% means high probability of reversal why not place opposite bet when stab happens?
* how to identify and avoid consolidation? hasent made any new heights in a while

//include risk management


*/
