//+------------------------------------------------------------------+
//|                                                Consolidation.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Candle.mqh>
#include <Generic/ArrayList.mqh>

#define DEFAULT_DRAW_COLOR clrWhite
#define BOX_RANGE_CHANGE_BUFFER_PERCENT 0.04

class ConsolidationContext {
private:
   CArrayList<double> consolidation_box_range_list;
   CArrayList<double> box_range_diff_list;
   
   double last_body_high;
   double last_body_low;
   
   double last_avg_slope;  //in pipettes
   
   int draw_color;
    
public:
   ConsolidationContext();
   
   bool IsConsolidation();
   void AddNewWindow(const Candle& candles[], const int size, const int offset = 0);
   
   void Clear();
   void Draw();
};

ConsolidationContext::ConsolidationContext(void) :
   last_body_high(0.0),
   last_body_low(0.0),
   draw_color(DEFAULT_DRAW_COLOR),
   last_avg_slope(0.0) {
}

bool
ConsolidationContext::IsConsolidation(void) {

   if(box_range_diff_list.Count() < 3) {
      return false;
   }
   
   int count = 0;
   double diff;
   for(int i = box_range_diff_list.Count() - 1; i >= 0; --i) {
      //con list: 10, 20, 30, 20
      //diff list: 10, 10, -10
      
      box_range_diff_list.TryGetValue(i, diff);
      
      if(diff > 0.0) {
      
         double box_range;
         consolidation_box_range_list.TryGetValue(i, box_range);
         if(diff > (box_range * BOX_RANGE_CHANGE_BUFFER_PERCENT)) {
            break;
         }     
      }
      
      count++;
      if(count == 3) {
      
         if(last_avg_slope <= 25.0) {
            return true;
         }
      }
   }

   return false;
}

void
ConsolidationContext::AddNewWindow(const Candle &candles[], const int size, const int offset = 0) {

   //calculate new consolidation bounds
   
   double body_high = MathMax(candles[offset].open, candles[offset].close);
   double body_low = MathMin(candles[offset].open, candles[offset].close);
   
   for(int i = offset + 1; i < (offset + size) - 1 ; ++i) {
      body_high = MathMax(body_high, MathMax(candles[i].open, candles[i].close));
      body_low = MathMin(body_low, MathMin(candles[i].open, candles[i].close));
   }
   
   last_body_high = body_high;
   last_body_low = body_low;
   
   double curr_range =  (body_high - body_low) * 100000; //in pipettes
   curr_range = NormalizeDouble(curr_range, 2);
   consolidation_box_range_list.Add(curr_range);
   
   double prev_range = 0.0;
   if(!consolidation_box_range_list.TryGetValue(consolidation_box_range_list.Count() - 2, prev_range)) {
      //not enough data yet 
      box_range_diff_list.Add(0.0);
      return;
   }
   
   double diff = curr_range - prev_range;
   box_range_diff_list.Add(diff);
   
   //calculate average slope for this window
   
   last_avg_slope = 0.0;
   for(int i = offset; i < (offset + size) - 1; ++i) {
      last_avg_slope += MathAbs(candles[i].GetMidPointBody() - candles[i + 1].GetMidPointBody()) * 100000; //in pipettes
   }
   
   last_avg_slope /= (ArraySize(candles) - 1);
   //Comment("Curr range: ", curr_range, "          Prev range: ", prev_range, "      Diff: ", NormalizeDouble(diff, 2), "       ", IsConsolidation());
   Comment("Avg slope: ", last_avg_slope);
}

void 
ConsolidationContext::Clear() {
   consolidation_box_range_list.Clear();
   box_range_diff_list.Clear();
   last_body_high = 0.0;
   last_body_low = 0.0;
   
   if(ObjectFind(0, "c_line_high") >= 0) {
      ObjectDelete(0, "c_line_high");
   }
   
   if(ObjectFind(0, "c_line_low") >= 0) {
      ObjectDelete(0, "c_line_low");
   }
}

void 
ConsolidationContext::Draw() {

   //static bool last_consolidation_stat = false;
   static int con_arrow_count = 0;
   
   if(ObjectFind(0, "c_line_high") < 0) {
      ObjectCreate(0, "c_line_high", OBJ_HLINE, 0, 0, last_body_high);
      ObjectSetInteger(0, "c_line_high", OBJPROP_COLOR, draw_color);
   } else {
      ObjectMove(0, "c_line_high", 0, 0, last_body_high);
   }
   
   if(ObjectFind(0, "c_line_low") < 0) {
      ObjectCreate(0, "c_line_low", OBJ_HLINE, 0, 0, last_body_low);
      ObjectSetInteger(0, "c_line_low", OBJPROP_COLOR, draw_color);
   } else {
      ObjectMove(0, "c_line_low", 0, 0, last_body_low);
   }
   
   if(IsConsolidation()) {

      string arrow_name = StringFormat("con_arrow_%d", con_arrow_count);
      
      MqlRates rate[1];
      CopyRates(_Symbol, _Period, 1, 1, rate);
   
      ObjectCreate(0, arrow_name, OBJ_ARROW_DOWN, 0, rate[0].time, rate[0].high + 0.0005);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, draw_color);
      con_arrow_count++;
   }
}