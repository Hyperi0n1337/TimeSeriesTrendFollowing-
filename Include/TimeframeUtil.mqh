//+------------------------------------------------------------------+
//|                                                TimeframeUtil.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

class TimeframeUtil {
public:
   
   TimeframeUtil() = delete;
   
   //Decides if current time lies within a new time frame from last recorded time
   static bool              IsNewTimeframe(const MqlDateTime& prev_time, const MqlDateTime& curr_time, const ENUM_TIMEFRAMES period);
   static bool              IsCurrPeriodNewTimeframe();
   static ENUM_TIMEFRAMES   PrevTimeframe(const ENUM_TIMEFRAMES curr_frame);
   static ENUM_TIMEFRAMES   NextTimeframe(const ENUM_TIMEFRAMES curr_frame);
};
   
bool 
TimeframeUtil::IsNewTimeframe(const MqlDateTime& prev_time, const MqlDateTime& curr_time, const ENUM_TIMEFRAMES period) {
   switch(period) {
      case PERIOD_M1:
      {
         if(curr_time.min != prev_time.min) {
            return true;
         }
         break;
      }
      case PERIOD_M2:
      case PERIOD_M3:
      case PERIOD_M4:
      case PERIOD_M5:
      case PERIOD_M6:
      case PERIOD_M10:
      case PERIOD_M12:
      case PERIOD_M15:
      case PERIOD_M20:        
      case PERIOD_M30:
      {
         //as it turns out for Minute 1 - Minute 30 timeframe the preriod enum is exactly the same number
         if(curr_time.min % (int) period == 0 && prev_time.min % (int) period != 0) {
            return true;
         }
         
         //the time elapsed between ticks happens to be larger than the timeframe
         int time_diff_sec = (int) (StructToTime(curr_time) - StructToTime(prev_time));
         if(time_diff_sec / 60 >= (int) period) {
            return true;
         }
         break;
      }
      case PERIOD_H1:
      {
         if(curr_time.hour != prev_time.hour) {
            return true;
         }
         break;
      }
      case PERIOD_H2:       
      case PERIOD_H3:         
      case PERIOD_H4:        
      case PERIOD_H6:        
      case PERIOD_H8:        
      case PERIOD_H12: 
      {
         
         //for hour 1 to hour 12 the number is encoded in the first byte
         //some sort of identifier is also encoded in the 2nd byte
         uchar hr_divisor = (uchar) period; 
         if(curr_time.hour % hr_divisor == 0 && prev_time.hour % hr_divisor != 0) {
            return true;
         }
         
         //the time elapsed between ticks happens to be larger than the timeframe
         int time_diff_sec = (int) (StructToTime(curr_time) - StructToTime(prev_time));
         if(time_diff_sec / 360 >= hr_divisor) {
            return true;
         }
         break;
      }
      case PERIOD_D1:
      {
         if(curr_time.day != prev_time.day) {
            return true;
         }
         break;
      }
      case PERIOD_W1:
      {
         if(curr_time.day_of_week == 0 && prev_time.day_of_week != 0) {
            return true;
         }
         break;  
      }
      case PERIOD_MN1:
      {
         if(curr_time.mon != prev_time.mon) {
            return true;
         }
         break;
      }
   }
   return false;
}

bool
TimeframeUtil::IsCurrPeriodNewTimeframe() {
   static MqlDateTime last_time;
   
   MqlDateTime curr_time;
   TimeCurrent(curr_time);   
   
   //check for new time frame
   bool ret = TimeframeUtil::IsNewTimeframe(last_time, curr_time, _Period);
   last_time = curr_time;
   return ret;
}

ENUM_TIMEFRAMES   
TimeframeUtil::PrevTimeframe(const ENUM_TIMEFRAMES curr_frame) {
   switch(curr_frame) {
      case PERIOD_M2:
      case PERIOD_M3:
      case PERIOD_M4:
      case PERIOD_M5:
      case PERIOD_M6:
      {
         return (ENUM_TIMEFRAMES) ( (int) curr_frame - 1 );
      }
      case PERIOD_M10: { return PERIOD_M6; }
      case PERIOD_M12: { return PERIOD_M10; }  
      case PERIOD_M15: { return PERIOD_M12; }
      case PERIOD_M20: { return PERIOD_M15; }        
      case PERIOD_M30: { return PERIOD_M20; }
      case PERIOD_H1: { return PERIOD_M30; }
      case PERIOD_H2: { return PERIOD_H1; }       
      case PERIOD_H3: { return PERIOD_H2; }         
      case PERIOD_H4: { return PERIOD_H3; }        
      case PERIOD_H6: { return PERIOD_H4; }        
      case PERIOD_H8: { return PERIOD_H6; }        
      case PERIOD_H12: { return PERIOD_H8; } 
      case PERIOD_D1: { return PERIOD_H12; } 
      case PERIOD_W1: { return PERIOD_D1; }
      case PERIOD_MN1: { return PERIOD_W1; }  
      
      default: { return PERIOD_M1; }
   }
   
   return PERIOD_M1;
}

ENUM_TIMEFRAMES   
TimeframeUtil::NextTimeframe(const ENUM_TIMEFRAMES curr_frame) {
   return PERIOD_CURRENT;
}