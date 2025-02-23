package ru.redspell.lightning.payments;

import android.content.Intent;
import android.os.Bundle;

import ru.redspell.lightning.NativeActivity;
import ru.redspell.lightning.IUiLifecycleHelper;
import ru.redspell.lightning.utils.Log;

import org.onepf.oms.OpenIabHelper;
import org.onepf.oms.appstore.googleUtils.IabHelper;
import org.onepf.oms.appstore.googleUtils.IabResult;
import org.onepf.oms.appstore.googleUtils.Purchase;
import org.onepf.oms.appstore.googleUtils.Inventory;
import org.onepf.oms.appstore.googleUtils.SkuDetails;
import org.onepf.oms.util.Logger;

import java.util.LinkedList;
import java.util.Arrays;
import java.util.Queue;
import java.util.Map;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import org.json.JSONObject;
import org.json.JSONException;


public class Openiab implements Payments.IPayments {

  final int RC_REQUEST = 10001;
  private OpenIabHelper helper = null;
  private Queue<Runnable> pendingQueue = new LinkedList<Runnable>();
  private boolean setupDone = false;
  private boolean setupFailed = false;
  private ISKULightDetailsExtractor skuDetailsExtractor = null;

	
  private class PurchaseCommand implements Runnable {
    private String sku;

    public PurchaseCommand(String sku) {
      this.sku = sku;
    }

    public void run() {
      Log.d("LIGHTNING", "Purchase command with sku " + sku);

      if (helper == null) return;

      String payload = "";
      IabHelper.OnIabPurchaseFinishedListener listener = new IabHelper.OnIabPurchaseFinishedListener() {
        public void onIabPurchaseFinished(IabResult result, Purchase purchase) {
          if (result.isSuccess()) {
            Payments.purchaseSuccess(sku, purchase, false);
          } else {
            Payments.purchaseFail(sku, result.getMessage());
          }
        }
      };

      helper.launchPurchaseFlow(NativeActivity.instance, sku, RC_REQUEST, listener, payload);
    }

    public String getSku() {
      return sku;
    }
  }

  private class ConsumeCommand implements Runnable {
    private Purchase purchase;

    public ConsumeCommand(Purchase purchase) {
      this.purchase = purchase;
    }

    public void run() {
      if (helper == null) return;
      helper.consumeAsync(purchase, new IabHelper.OnConsumeFinishedListener() {
         public void onConsumeFinished(Purchase purchase, IabResult result) {}
      });
    }
  }

  private class InventoryCommand implements Runnable {
    private String[] detailsForSkus = null;
    private boolean forOwnedPurchases = false;

    public InventoryCommand(String[] detailsForSkus) {
      this.detailsForSkus = detailsForSkus;
    }

    public InventoryCommand() {
      forOwnedPurchases = true;
    }

    /*
     *
     */
    public void run() {

      if (helper == null) {
        return;
      }
      
      
      IabHelper.QueryInventoryFinishedListener listener = new IabHelper.QueryInventoryFinishedListener() {

        public void onQueryInventoryFinished(IabResult result, Inventory inventory) {
          
          Log.d("LIGHTNING", "onQueryInventoryFinished " + result.isSuccess());
          
          if (!result.isSuccess()) {
            return;
          }

          if (detailsForSkus != null) {

            for (int i = 0; i < detailsForSkus.length; i++) {

              SkuDetails details = inventory.getSkuDetails(detailsForSkus[i]);
              if (details == null) {
                 continue;
              }
              
              String price = details.getPrice();
              if (price == null) {
                continue;
              }

              Payments.purchaseRegister(detailsForSkus[i], price);
              
              String rawJson = details.getJson();              
              
              if (rawJson == null) {
        	    String dollar = "$";
        		if (price.startsWith(dollar)) {
        		    try {
      		          double d_amount = Double.parseDouble (price.substring(1));
          	          Payments.purchaseDetailsRegister(detailsForSkus[i], new Payments.LightDetails ("USD", d_amount));
          	        } catch (java.lang.RuntimeException exc) {
          	          Log.d("LIGHTNING", "JSON exc" + (exc.toString ()));
          	        }
	          	}
      		    continue;
          	  }
	            
	          //   
	          try 
              {
                Payments.LightDetails pld = skuDetailsExtractor.parse(rawJson);
                if (pld != null) {
  	    	      Payments.purchaseDetailsRegister(detailsForSkus[i], pld);
  	    	    }
              } catch (JSONException exc) {
				  Log.d("LIGHTNING", "[1] JSON exc" + (exc.toString ()));
			  } catch (java.lang.RuntimeException exc) {
          	      Log.d("LIGHTNING", "[2] JSON exc" + (exc.toString ()));
          	  }              

				
            }
              
          } else if (forOwnedPurchases) {
            Iterator<Purchase> iter = inventory.getAllPurchases().iterator();
            while (iter.hasNext()) {
              Purchase purchase = iter.next();
              Payments.purchaseSuccess(purchase.getSku(), purchase, true);
            }
          }
        }
      };

      helper.queryInventoryAsync(detailsForSkus != null, detailsForSkus != null ? Arrays.asList(detailsForSkus) : null, listener);
    }
  }

  private void runPending() {
    Runnable pending;

    while ((pending = pendingQueue.poll()) != null) {
      pending.run();
    }
  }

  private void failPendings() {
    Runnable pending;

    while ((pending = pendingQueue.poll()) != null) {
      if (pending instanceof PurchaseCommand) {
        PurchaseCommand purchase = (PurchaseCommand)pending;
        Payments.purchaseFail(purchase.getSku(), "pending purchase failed cause setup failed");
      }
    }
  }


  // -------- Парсилка JSON, в котором SKU ---------------- //
  // -------- Просто в базаре по-другому цена присылается - //
  private interface ISKULightDetailsExtractor {
    public Payments.LightDetails parse(String rawJSON)  throws JSONException;
  }

  /*
   *
   */
  private class DefaultSKULightDetailsExtractor implements ISKULightDetailsExtractor {
  
    public Payments.LightDetails parse(String rawJson) throws JSONException {
      JSONObject json = new JSONObject (rawJson);
      long amount = json.getLong ("price_amount_micros");
	  String currency = json.getString ("price_currency_code");
	  double d_amount = amount / 1000000.;
	  Log.d("LIGHTNING", "java amount " + amount + " " + d_amount);
	  return new Payments.LightDetails (currency, d_amount);
    }
    
  }




  
  /*
   * В кафе базар в JSON цена приходит с указанием валюты и в зависимости от выбраной в самом базаре локали может 
   * быть представлена как фарсишными символами, так и не очень :)
   *
   * Могут быть 4 варианта. Два для нулевой цены, и два для ненулевой
   * Нулевая цена для английского языка: 'Zero Rials'
   * Ненулевая цена для английского языка: '10,000 Rials' - десять тысяч!
   * Нулевая цена для фарси: "صفر ری" - такая вот загогулина панимаишь
   * Ненулевая цена для фарси (14 тысяч, тоже есть делимитер): "۱۴٬۰۰۰ ری";
   * Но это еще не весь пиздец. Парни из ирана просят сконвертить итоговую цены в другую местную валюту, томаны
   * 10,000 IRR = 1000 Toman = 1,000 تومان
   *
   * Поэтому при выводе цен для иранской фермы независимо от локали и от версии приложения надо ставить флаг, что рисуем фарси!
   *
   */
  private class CafeBazaarSKULightDetailsExtractor implements ISKULightDetailsExtractor {

    private class NotFarsiNumericSymbolException extends Exception {
      
      public char symbol;
      
      public NotFarsiNumericSymbolException(char s) {
        this.symbol = s;
      }
    }

    //
    //
    //
    private int convertFarsiNumericSymbol(char sym) throws NotFarsiNumericSymbolException {
      char[] persianChars = {'۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'};
      for (int i = 0; i < persianChars.length; i++) {
        if (sym == persianChars[i]) {
          return i;
        }
      }
      throw new NotFarsiNumericSymbolException(sym);
    }


    //
    //
    //
    private boolean isFarsiPrice(String price) { 
      return price.indexOf("ials") == -1; //  Если нет rials или Rials, то считаем, что фарси
    }

    //
    //
    //
    private int parseFarsiBazaarPrice(String price) {

      int number = 0;
      int power  = 0;
      
      for (int i = price.length() - 1; i >= 0; i--) {
        
        char sym = price.charAt(i);

        if (sym == '٬') {    // это фарсишный делимитер, запятая
          continue;
        }
        
        try {
          int num = convertFarsiNumericSymbol(sym);
          number += Math.pow(10, power) * num;
          power++;
        } catch (NotFarsiNumericSymbolException exn) {
          return 0;
        }    
      }
    
      return number;
    }
    

    //
    //
    //    
    private int parseEnglishBazaarPrice(String price) {
      if (price.equalsIgnoreCase("zero")) {
        return 0;
      }      
      return Integer.parseInt(price.replaceAll(",", ""));
    }




    //
    //
    //
    public Payments.LightDetails parse(String rawJson) throws JSONException {

      long amountRials = 0;
      long amountTomans = 0;
            
      JSONObject json = new JSONObject (rawJson);
      String currencyTomans = "تومان";
      String price = json.getString ("price");	
      String[] pair = price.split(" ");

      if (isFarsiPrice(price)) {

        amountRials = parseFarsiBazaarPrice(pair[0]);
      } else {
        amountRials = parseEnglishBazaarPrice(pair[0]);
      }
        
      amountTomans = amountRials / 10;
      return new Payments.LightDetails (currencyTomans, amountTomans);
    }
  }  



  /*
   *
   */
  public void init(String[] _skus, String marketType) {
     try {
         final String[] skus = _skus;



         Log.d("LIGHTNING", "init call " + marketType + " isSamsungTestMode " + org.onepf.oms.appstore.SamsungApps.isSamsungTestMode);
         
         if (helper != null) return;

         Log.d("LIGHTNING", "continue");
				 Logger.setLoggable(true);

         setupFailed = false;
         ArrayList<String> prefStores = new ArrayList<String>(1);
         prefStores.add(marketType);
         
		 String[] prefStoresArr = prefStores.toArray (new String[prefStores.size()]);

         //to be able use samsung store at least one sku mapping needed. it is absolutely fake needed only to workaround openiab strange behaviour
         OpenIabHelper.mapSku("ru.redspell.lightning.fameSamsungPurchase", OpenIabHelper.NAME_SAMSUNG, "100000104912/ru.redspell.lightning.fameSamsungPurchase");

         OpenIabHelper.Options.Builder builder = new OpenIabHelper.Options.Builder()
             .addPreferredStoreName(prefStoresArr)
    		 .setStoreSearchStrategy(OpenIabHelper.Options.SEARCH_STRATEGY_INSTALLER_THEN_BEST_FIT)
             .setVerifyMode(OpenIabHelper.Options.VERIFY_SKIP);
        
         if (marketType.equals(ru.redspell.lightning.payments.openiab.appstore.BazaarAppStore.NAME_BAZAAR)) {
            
             builder.addAvailableStoreNames(ru.redspell.lightning.payments.openiab.appstore.BazaarAppStore.NAME_BAZAAR)
            .addAvailableStores(new ru.redspell.lightning.payments.openiab.appstore.BazaarAppStore(NativeActivity.instance, null));
  
            skuDetailsExtractor = new CafeBazaarSKULightDetailsExtractor();
            
         } else {
            skuDetailsExtractor = new DefaultSKULightDetailsExtractor();            
         }

         OpenIabHelper.Options opts = opts = builder.build();
         OpenIabHelper.enableDebugLogging(true);

         helper = new OpenIabHelper(NativeActivity.instance, opts);
         

         NativeActivity.instance.addUiLifecycleHelper(new IUiLifecycleHelper() {
             public void onCreate(Bundle savedInstanceState) {}
             public void onResume() {}
             public void onActivityResult(int requestCode, int resultCode, Intent data) {
                 Log.d("LIGHTNING", "openiab onActivityResult " + requestCode + " resultCode " + resultCode + " data " + data);
                 helper.handleActivityResult(requestCode, resultCode, data);
             }
             public void onSaveInstanceState(Bundle outState) {}
             public void onPause() {}
             public void onStop() {}
             public void onDestroy() {}
			 public void onStart() {}
         });

         helper.startSetup(new IabHelper.OnIabSetupFinishedListener() {
                     public void onIabSetupFinished(IabResult result) {
                         if (!result.isSuccess()) {
                             failPendings();
                             setupFailed = true;
                             return;
                         }

                         setupDone = true;
                         runPending();
                         request(new InventoryCommand(skus));
                     }
                 });
     } catch (Exception e ) {}

  }

  private void request(Runnable request) {
    if (setupDone) {
        request.run();
    } else if (setupFailed) {
        if (request instanceof PurchaseCommand) {
          PurchaseCommand purchase = (PurchaseCommand)request;
          Payments.purchaseFail(purchase.getSku(), "purchase failed cause setup failed");
        }
    } else {
        pendingQueue.add(request);
    }
  }

  public void purchase(String sku) {
    request(new PurchaseCommand(sku));
  }

  public void consume(Object purchase) {
    request(new ConsumeCommand((Purchase)purchase));
  }

  public void inventory() {
    request(new InventoryCommand());
  }

  public String getOriginalJson(Object purchase) {
      return ((Purchase)purchase).getOriginalJson();
  }

  public String getToken(Object purchase) {
      return ((Purchase)purchase).getToken();
  }

  public String getSignature(Object purchase) {
      return ((Purchase)purchase).getSignature();
  }
}
