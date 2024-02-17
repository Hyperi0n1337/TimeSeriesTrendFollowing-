//+------------------------------------------------------------------+
//|                                                   SeriesUtil.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

namespace SeriesUtil {
   
   //converts a series of data points to between 1 and -1 based on the source series
   void NormalizeSeries(double& dest[], const double& src[], const bool percentage = false) {
      double high = -DBL_MAX;
      double low = DBL_MAX;
      
      for(int i = 0; i < ArraySize(src); ++i) {
         if(src[i] > high) {
            high = src[i];
         }
         
         if(src[i] < low) {
            low = src[i];
         }
      }
   
      double range = high - low;
      for(int i = 0; i < ArraySize(src); ++i) {
      
         if(low > 0) {
            dest[i] = (src[i] - low) / range;
         } else if(high < 0) {
            dest[i] = (src[i] - high) / range;
         } else {
            dest[i] = src[i] / range; 
         }
         
         if(percentage) {
            dest[i] *= 100;
         }
      }
   }
   
   void GetSeriesDifference(double& dest[], const double& src[], const unsigned int start, const unsigned int count, const bool abs = false ) {
      unsigned int dest_i = 0;
      for(unsigned int i = start; i < (start + count) - 1; ++i) {
         dest[dest_i] = src[i + 1] - src[i];
         dest_i++;
      }
   }
}