//+------------------------------------------------------------------+
//|                                                       Candle.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

class Candle {
   
public:
   double open;
   double close;
   double high;
   double low;

   Candle() {}
   
   Candle(double o, double c, double h, double l):
      open(o),
      close(c),
      high(h),
      low(l) 
   {
   }
   
   inline double Range() const {
      return high - low;
   }
   
   inline double BodyRange() const {
      return MathAbs(open - close);
   }
   
   double LowerShadowRange() const;
   
   double UpperShadowRange() const;
   
   double BodyToRangeRatio() const;
   
   double GetMidPointBody() const;
   
   double GetMidPointRange() const;
   
   inline double LowerShadowToRangeRatio() const{
      if(Range() == 0.0) {
         return 0.0;
      }
      return LowerShadowRange() / Range();
   }
   
   inline double UpperShadowToRangeRatio() const{
      if(Range() == 0.0) {
         return 0.0;
      }
      return UpperShadowRange() / Range();
   }

   inline bool IsBullish() const {
      return (close != open && close > open);
   }
   
   inline bool IsBearish() const {
      return (close != open && close < open);
   }
   
   string ToString() const;
};

string
Candle::ToString(void) const {
   return StringFormat("O: %f\tC: %f\tH: %f\tL: %f", open, close, high, low);
}

double
Candle::BodyToRangeRatio(void) const {
   double range_diff = Range();
   double body_diff = BodyRange();
   
   if(range_diff == 0.0) {
      return 1.0;
   }
   
   if(body_diff == 0.0) {
      return 0.0;
   }
   
   return  body_diff / range_diff;
}

double 
Candle::GetMidPointBody() const {
   double range = BodyRange() / 2;
   
   if(IsBearish()) {
      return open - range;
   } else if (IsBullish()) {
      return open + range;
   } else {
      return open;
   }
}
   
double 
Candle::GetMidPointRange() const {
   double range = Range() / 2;
   
   if(IsBearish()) {
      return high - range;
   } else if (IsBullish()) {
      return low + range;
   } else {
      return low;
   }
}

double
Candle::LowerShadowRange(void) const {
   if(IsBullish()) {
      return open - low;
   } else {
      return close - low;
   }
}
double
Candle::UpperShadowRange(void) const {
   if(IsBullish()) {
      return high - close;
   } else {
      return high - open;
   }
}

namespace CandleUtil {
   
   void FormLatestCandle(Candle& c, const string& symbol, const ENUM_TIMEFRAMES period) {
      c.open = iOpen(symbol, period, 1);
      c.close = iClose(symbol, period, 1);
      c.high= iHigh(symbol, period, 1);
      c.low = iLow(symbol, period, 1);   
   }
   
   void FormCandles(Candle& out[], const string& symbol, const ENUM_TIMEFRAMES period, const int size, const int offset = 0) {
      double open_buff[];
      double close_buff[];
      double high_buff[];
      double low_buff[];
      
      ArrayResize(open_buff, size);
      ArrayResize(close_buff, size);
      ArrayResize(high_buff, size);
      ArrayResize(low_buff, size);
      
      CopyOpen(symbol, period, offset, size, open_buff);
      CopyClose(symbol, period, offset, size, close_buff);
      CopyHigh(symbol, period, offset, size, high_buff);
      CopyLow(symbol, period, offset, size, low_buff);
      
      int out_idx = size - 1;
      for(int i = 0; i < size; ++i) {
      
         out[out_idx] = Candle(open_buff[i], close_buff[i], high_buff[i], low_buff[i]);
         out_idx--;
      }
      
      ArrayFree(open_buff);
      ArrayFree(close_buff);
      ArrayFree(high_buff);
      ArrayFree(low_buff);
   }
}