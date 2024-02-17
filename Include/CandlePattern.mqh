//+------------------------------------------------------------------+
//|                                                CandlePattern.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Candle.mqh>

#define BIG_SHADOW_LOWER_SHADOW_RANGE_RATIO     0.33
#define BIG_SHADOW_UPPER_SHADOW_RANGE_RATIO     0.33
#define BIG_SHADOW_COVERAGE_RATIO_THRESH        0.5
#define KANGAROO_COVERAGE_RATIO_THRESH          0.4
#define ENGULFING_THRESH                        1.5

enum ENUM_CANDLE_PATTERN_TYPE {
   CPT_ALL,
   CPT_BULLISH,
   CPT_BEARISH
};

struct CandlePatternConfig {
   ENUM_CANDLE_PATTERN_TYPE setup_type; 
};

struct BigShadowConfig: CandlePatternConfig {
   bool  ignore_sr;
   bool  use_coverage;
   double max_coverage_ratio;
   
   BigShadowConfig() : 
      ignore_sr(false),
      use_coverage(true),
      max_coverage_ratio(BIG_SHADOW_COVERAGE_RATIO_THRESH)
   {}
};

struct KangarooConfig: CandlePatternConfig {
   bool  ignore_sr;
   bool  use_coverage;
   double max_coverage_ratio;
   
   KangarooConfig() :
      ignore_sr(false),
      use_coverage(true),
      max_coverage_ratio(KANGAROO_COVERAGE_RATIO_THRESH)
   {}   
};

struct EngulfingConfig: CandlePatternConfig {
   bool  ignore_sr;
   float engulfing_factor;
   
   EngulfingConfig() :
      ignore_sr(false),
      engulfing_factor(ENGULFING_THRESH)
   {}   
   
};

class CandlePattern {
   
public:

   CandlePattern() = delete;

   //at least two candles
   static bool IsBigShadow(const Candle& candles[], const int size, const BigShadowConfig& config) {  
      
      const Candle *curr_candle = &candles[0];
      const Candle *prev_candle = &candles[1];
      
      //check if first candle's range engulfs previous candle's range
      if(curr_candle.high <= prev_candle.high || curr_candle.low >= prev_candle.low){
         return false;
      }
      
      if(config.setup_type == CPT_BULLISH && !curr_candle.IsBullish()) {
         return false;
      }
      
      if(config.setup_type == CPT_BEARISH && !curr_candle.IsBearish()) {
         return false;
      }
      
      if(   curr_candle.IsBullish() &&  
            ( !prev_candle.IsBearish() ||  //previous candle has to be opposite of the current candle
            curr_candle.UpperShadowToRangeRatio() > BIG_SHADOW_UPPER_SHADOW_RANGE_RATIO ) ) 
      {
         return false;
      }
      
      if(   curr_candle.IsBearish() && 
            ( !prev_candle.IsBullish() ||  //previous candle has to be opposite of the current candle
            curr_candle.LowerShadowToRangeRatio() > BIG_SHADOW_LOWER_SHADOW_RANGE_RATIO ) ) 
      {
         return false;
      }
      
      if(!config.ignore_sr) {
      
      //TODO: check print on S/R zone
      }
      
      if(config.use_coverage) {
         if(CoverageRatio(candles, size, 2) > config.max_coverage_ratio) {
            return false;
         }
      }
      return true;
   }
   
   static bool IsKangarooTail(const Candle& candles[], const int size, const KangarooConfig& config) {
      const Candle *curr_candle = &candles[0];
      
      //Print("Lower ", curr_candle.BodyToRangeRatio() + curr_candle.LowerShadowToRangeRatio());
      //Print("Upper ", curr_candle.BodyToRangeRatio() + curr_candle.UpperShadowToRangeRatio());
      
      //TODO: current body 1/3 or 1/3 of previous body
      
      //make sure real body is within upper / lower one third of the range
      if(   ( ( curr_candle.BodyToRangeRatio() + curr_candle.LowerShadowToRangeRatio() ) > 0.33 ) && 
            ( ( curr_candle.BodyToRangeRatio() + curr_candle.UpperShadowToRangeRatio() ) > 0.33 ) )
      {
         return false;
      }
      
      if(config.setup_type == CPT_BEARISH && (curr_candle.LowerShadowRange() > curr_candle.UpperShadowRange()) ) {
         return false;
      }
      
      if(config.setup_type == CPT_BULLISH && (curr_candle.UpperShadowRange() > curr_candle.LowerShadowRange()) ) {
         return false;
      }
      
      //TODO: S/R check
      
      const Candle *prev_candle = &candles[1];
      
      //kangaroo candle must be within previcous candle's range
      if(   curr_candle.open > prev_candle.high ||
            curr_candle.open < prev_candle.low ||
            curr_candle.close > prev_candle.high ||
            curr_candle.close < prev_candle.low ) 
      {
         return false;
      }
      
      if(config.use_coverage) {
      
         if(CoverageRatio(candles, size, 1) > config.max_coverage_ratio) {
            return false;
         }
      }
      return true;
   }
   
   static bool IsEngulfing(const Candle& candles[], const int size, const EngulfingConfig& config) {
      const Candle *curr_candle = &candles[0];
      const Candle *prev_candle = &candles[1];
      
      if(config.setup_type == CPT_BULLISH && !curr_candle.IsBullish()) {
         return false;
      }
      
      if(config.setup_type == CPT_BEARISH && !curr_candle.IsBearish()) {
         return false;
      }
      
      if(   (curr_candle.IsBullish() && !prev_candle.IsBearish()) || 
            (curr_candle.IsBearish() && !prev_candle.IsBullish()) ) {
            return false;
      }
      
      if(curr_candle.BodyRange() / prev_candle.BodyRange() < config.engulfing_factor) {
         return false;
      }
      
      return true;
   }
   
   static float CoverageRatio(const Candle& candles[], const int size, const int start) {
      const Candle *curr_candle = &candles[0];
   
      double curr_high_cap = curr_candle.low;
      double curr_low_cap = curr_candle.high;
      
      bool high_engulf_flag = false, low_engulf_flag = false;
      
      for(int i = start; i < size; ++i) {
        
         if(!high_engulf_flag && candles[i].high > curr_high_cap) {
            curr_high_cap = candles[i].high;
            
            if(curr_high_cap >= curr_candle.high) {
               high_engulf_flag = true;
            }
         }
   
         if(!low_engulf_flag && candles[i].low < curr_low_cap) {
            curr_low_cap = candles[i].low;
            
            if(curr_low_cap <= curr_candle.low) {
               low_engulf_flag = true;
            }
         }
      }
      
      if(high_engulf_flag && low_engulf_flag) {
         return 1.0;
      }
      
      if(high_engulf_flag) {
         return (float) ( 1.0 - ( (curr_low_cap - curr_candle.low) / curr_candle.Range() ) );    
      }
      
      if(low_engulf_flag) {
         return (float) ( 1.0 - ( (curr_candle.high - curr_high_cap) / curr_candle.Range() ) );
      }
      
      return (float) ( (curr_high_cap - curr_low_cap) / curr_candle.Range() );
   }
};