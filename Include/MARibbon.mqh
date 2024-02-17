//+------------------------------------------------------------------+
//|                                                     MARibbon.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+

#include <SeriesUtil.mqh>

#define REVERSAL_LOOKBACK_BUFFER_SIZE 32

struct MA_INFO {
   int indicator_handle;
   int period;
   
   MA_INFO() :
      indicator_handle(INVALID_HANDLE),
      period(-1)
   {}
};

enum ENUM_RIBBON_TREND {
   RT_NONE, //none trend when MAs are crossed
   RT_UP,
   RT_DOWN
};

class MARibbon {
   
   MA_INFO           ma_arr[];
   int               ma_count;
   string            symbol;
   ENUM_TIMEFRAMES   time_frame;
   
public:
   
   MARibbon(const int size, string symbol);
   ~MARibbon();
   
   inline int GetMACount() const {
      return ArraySize(ma_arr);
   }

   void           GetMA(double& dest[], const int offset) const;
   void           GetMAMinMax(const int offset, double& min, double& max) const;
   
   void           SetTimeFrame(const ENUM_TIMEFRAMES timeframe);
   void           SetPeriod(const int index, const int period);
   
   bool           IsCurrUpTrend();
   bool           IsCurrDownTrend();
   
   double         GetGapSum(const unsigned int offset);
   void           GetGapSums(double& out[], const unsigned int size, const unsigned int offset);
   void           GetGapSumDifference(double& out[], const double& gap_sum[]);
   
   int            GetCurrTrendBeginningOffset();
};


MARibbon::MARibbon(const int s, string sym):
   ma_count(s),
   symbol(sym)
{
   ArrayResize(ma_arr, s);
   
   for(int i = 0; i < s; ++i) {
      ma_arr[i] = MA_INFO();
   }
}

MARibbon::~MARibbon() {

   for(int i = 0; i < GetMACount(); ++i) {
      if(ma_arr[i].indicator_handle != INVALID_HANDLE) {
         IndicatorRelease(ma_arr[i].indicator_handle);
      }
   }
   
   ArrayFree(ma_arr);
}

void
MARibbon::GetMA(double& dest[], const int offset) const {

   double tmp[1];
   for(int i = 0; i < GetMACount(); ++i) {
      CopyBuffer(ma_arr[i].indicator_handle, 0, offset, 1, tmp);
      dest[i] = tmp[0];
   }
}

void           
MARibbon::GetMAMinMax(const int offset, double& min, double& max) const {
   double ma_buff[];
   ArrayResize(ma_buff, GetMACount());
   GetMA(ma_buff, offset);
   ArraySort(ma_buff);
   min = ma_buff[0];
   max = ma_buff[ArraySize(ma_buff) - 1];
}

void     
MARibbon::SetTimeFrame(const ENUM_TIMEFRAMES t) {
   time_frame = t;
}

void
MARibbon::SetPeriod(const int index, const int period) {
   if(ma_arr[index].indicator_handle != INVALID_HANDLE) {
      IndicatorRelease(ma_arr[index].indicator_handle);
   }
   
   ma_arr[index].period = period;
   ma_arr[index].indicator_handle = iMA(symbol, time_frame, period, 0, MODE_EMA, PRICE_CLOSE);
}

bool     
MARibbon::IsCurrUpTrend() {

   //assume ma_arr is already sorted by period
   
   double tmp1[1], tmp2[1];
   CopyBuffer(ma_arr[0].indicator_handle, 0, 1, 1, tmp1);
   
   for(int i = 1; i < ArraySize(ma_arr); ++i) {
   
      CopyBuffer(ma_arr[i].indicator_handle, 0, 1, 1, tmp2); 
      if(tmp1[0] < tmp2[0]) {
         return false;
      }
      
      tmp1[0] = tmp2[0];
   }
   return true;
}

bool     
MARibbon::IsCurrDownTrend() {

   //assume ma_arr is already sorted by period

   double tmp1[1], tmp2[1];
   CopyBuffer(ma_arr[0].indicator_handle, 0, 1, 1, tmp1);
   
   for(int i = 1; i < ArraySize(ma_arr); ++i) {
   
      CopyBuffer(ma_arr[i].indicator_handle, 0, 1, 1, tmp2); 
      if(tmp1[0] > tmp2[0]) {
         return false;
      }
      
      tmp1[0] = tmp2[0];
   }
   return true;
}

double         
MARibbon::GetGapSum(const unsigned int offset) {

   double mas[];
   ArrayResize(mas, ma_count);
   
   GetMA(mas, offset);
   double high = mas[0];
   double low = mas[0];
   
   for(int i = 1; i < ma_count; ++i) {
      high = MathMax(high, mas[i]);
      low = MathMin(low, mas[i]);
   }
   
   return high - low;
}

void     
MARibbon::GetGapSums(double& out[], const unsigned int size /*in candles*/, const unsigned int offset) {

   double data_buff[], high_buff[], low_buff[];
   ArrayResize(data_buff, size); 
   ArrayResize(high_buff, size);
   ArrayResize(low_buff, size);
   
   ArrayInitialize(out, 0.0);    //necessary?
   
   CopyBuffer(ma_arr[0].indicator_handle, 0, offset, size, data_buff);
   ArrayCopy(high_buff, data_buff);
   ArrayCopy(low_buff, data_buff);
   
   for(int i = 1; i < ma_count; ++i) {
      CopyBuffer(ma_arr[i].indicator_handle, 0, offset, size, data_buff);
     
      for(unsigned int j = 0; j < size; ++j) {
         high_buff[j] = MathMax(data_buff[j], high_buff[j]);
         low_buff[j] = MathMin(data_buff[j], low_buff[j]);
      }
   }
   
   for(unsigned int i = 0; i < size; ++i) {
         out[i] = high_buff[i] - low_buff[i];
   }
   
   ArrayFree(data_buff);
   ArrayFree(high_buff);
   ArrayFree(low_buff);
}

void
MARibbon::GetGapSumDifference(double& out[], const double& gap_sum[]) {
   for(int i = 0; i < ArraySize(gap_sum) - 1; ++i) {
      out[i] = gap_sum[i + 1] - gap_sum[i];
   }
}

int 
MARibbon::GetCurrTrendBeginningOffset(void) {
   int offset = 1;
   
   ENUM_RIBBON_TREND curr_trend;
   
   if(IsCurrDownTrend()) {
      curr_trend = RT_DOWN;
   } else if(IsCurrUpTrend()) {
      curr_trend = RT_UP;
   } else {
   
      //current trend cannot be determined, we are in middle of a reversal
      return -1;
   }
   
   /*
      Problem: Naive approach is to allocate a (huge) buffer and store a set time period
      of data in it. Then iterate through every period and check for overlap of each MA.
      Due to the limitation of copying mechanism from indicators, which ever arrange of
      memory data in memory will result in lots of cache misses either in iteration phase
      or collection phase (copying from indicator).
      
      
      Solution: Since the longer moving averages always lags behind shorter moving averages
      we only need to look at where the two longest period moving averages cross to
      determine the beginning of a reversed trend.
   */
   
   double buffer1[]; 
   double buffer2[]; 
   
   ArrayResize(buffer1, REVERSAL_LOOKBACK_BUFFER_SIZE);
   ArrayResize(buffer2, REVERSAL_LOOKBACK_BUFFER_SIZE);
   
   //find two largest period cross
   bool large_period_cross_flag = false;
   
   while(!large_period_cross_flag) {
   
      //buffer1 biggest period
      CopyBuffer(ma_arr[ma_count - 1].indicator_handle, 0, offset, REVERSAL_LOOKBACK_BUFFER_SIZE, buffer1);
      
      //buffer2 second biggest period 
      CopyBuffer(ma_arr[ma_count - 2].indicator_handle, 0, offset, REVERSAL_LOOKBACK_BUFFER_SIZE, buffer2);
   
      for(int i = REVERSAL_LOOKBACK_BUFFER_SIZE - 1; i >= 0; --i) {
      
         if(   (curr_trend == RT_DOWN && buffer1[i] < buffer2[i] ) || 
               (curr_trend == RT_UP && buffer1[i] > buffer2[i]) ) {
           
            large_period_cross_flag = true;
            break;          
         }
         
         offset++;
      }
   }
   
   ArrayFree(buffer1);
   ArrayFree(buffer2);
   return offset;
}