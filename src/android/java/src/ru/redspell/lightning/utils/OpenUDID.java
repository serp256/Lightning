package ru.redspell.lightning.utils;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.UUID;

import android.bluetooth.BluetoothAdapter;
import android.telephony.TelephonyManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.PackageManager.NameNotFoundException;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.provider.Settings.Secure;
import android.text.TextUtils;

import java.util.List;
import ru.redspell.lightning.utils.Log;

public class OpenUDID {
	public final static String LOG_TAG = "LIGHTNING";
	public final static String PREF_KEY = "openudid";
	public final static String PREFS_NAME = "openudid_prefs";
	
	private static String _openUdid;
	private final static boolean _UseImeiFailback = false;// false if you don't wanna include READ_PHONE_STATE permission
	//we recommend adding BT permission over  READ_PHONE_STATE permission as the will be less privacy concerns
	private final static boolean _UseBlueToothFailback = false; // false if you don't wanna include BT permission or android 1.6
	private final static boolean LOG = true; //Display or not debug message

	public static void syncContext(Context mContext){
		if(_openUdid==null){
			Context openContext = null;
			try {
				openContext = mContext.createPackageContext("ru.redspell.lightning", Context.CONTEXT_IGNORE_SECURITY );
				mContext = openContext;
			} catch (NameNotFoundException e1) {

			}

			SharedPreferences mPreferences =  mContext.getSharedPreferences(PREFS_NAME, Context.MODE_WORLD_READABLE);
			String _keyInPref = mPreferences.getString(PREF_KEY, null);
			if(null == _keyInPref){
				generateOpenUDIDInContext(mContext);
				Editor e = mPreferences.edit();
				e.putString(PREF_KEY, _openUdid);
				e.commit();
			}else{
				_openUdid = _keyInPref;
			}
		}
	}
	public static String getOpenUDIDInContext() {
		
		return _openUdid;
	}
	
	public static String getCorpUDID(String corpIdentifier){
		return Md5( String.format("%s.%s",corpIdentifier,getOpenUDIDInContext()));
	}
	/*
	 * Generate a new OpenUDID
	 */
	private static void generateOpenUDIDInContext(Context mContext) {
		Log.d(LOG_TAG,"Generating openUDID");
		List<String> ids = new java.util.ArrayList();

		//Try to get the ANDROID_ID
		String androidId = Secure.getString(mContext.getContentResolver(), Secure.ANDROID_ID).toLowerCase(); 
		if(null!=androidId && androidId.length()>14 && !androidId.equals("9774d56d682e549c")/*android 2.2*/) ids.add(androidId);

		//Try to get WIFI MAC
		String wifiID = generateWifiId(mContext);
		if (wifiID != null) ids.add(wifiID);
		

		String imei = generateImeiId(mContext);
		if (imei != null) ids.add(imei);

		if (ids.isEmpty()) generateRandomNumber();
		else {
			_openUdid = TextUtils.join(".",ids);
		}

		/*
		if(_UseImeiFailback){
			_openUdid = null;
			generateImeiId(mContext);

			if(_openUdid != null){
				return;
			}
		}
		
		if (_UseBlueToothFailback ){
			_openUdid = null;
			generateBlueToothId();
			if(_openUdid == null){
				generateRandomNumber();
			}
		}else{
			generateRandomNumber();
		}
		*/
		
		
		Log.d(LOG_TAG,_openUdid);
		
	}
	
	private static String generateImeiId(Context mContext) {
		// TODO Auto-generated method stub
		try{
			TelephonyManager TelephonyMgr = (TelephonyManager)mContext.getSystemService(Context.TELEPHONY_SERVICE);
			String szImei = TelephonyMgr.getDeviceId(); // Requires READ_PHONE_STATE

    	if(null!=szImei && ! szImei.substring(0, 3).equals("000")){
    		return "I".concat(szImei);
    	}
		}catch(Exception ex){
		}
		return null;
	}

	/*
	private static void generateBlueToothId() {
		try{
			BluetoothAdapter m_BluetoothAdapter	= null; // Local Bluetooth adapter
    	m_BluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
    	String m_szBTMAC = m_BluetoothAdapter.getAddress();
    	if(null!=m_szBTMAC){
    		_openUdid = "BTMAC:"+m_szBTMAC;

    	}
		}catch(Exception ex){
		
		}
	}
	*/

	private static String generateWifiId(Context mContext){
		try{
			WifiManager wifiMan = (WifiManager) mContext.getSystemService(Context.WIFI_SERVICE);
			WifiInfo wifiInf = wifiMan.getConnectionInfo();

			//Log.d(String.format("%s",wifiInf.getMacAddress()));
		
			String macAddr = wifiInf.getMacAddress();
			if(macAddr!=null){
				macAddr = macAddr.replace(":",""); //TextUtils.join("",macAddr.split(":"));
			}
			return "W".concat(macAddr);
		}catch(Exception ex){
			return null;
		}
	}
	
	private static String Md5(String input){
		MessageDigest m = null;
		try {
			m = MessageDigest.getInstance("MD5");
		} catch (NoSuchAlgorithmException e) {
			e.printStackTrace();
		}
		m.update(input.getBytes(),0,input.length());
		byte p_md5Data[] = m.digest();
		
		String mOutput = new String();
		for (int i=0;i < p_md5Data.length;i++) {
			int b =  (0xFF & p_md5Data[i]);
			// if it is a single digit, make sure it have 0 in front (proper padding)
			if (b <= 0xF) mOutput+="0";
			// add number to string
			mOutput+=Integer.toHexString(b);
		}
		// hex string to uppercase
		return mOutput.toUpperCase();
	}
	
	
	private static void generateRandomNumber(){
		_openUdid = Md5(UUID.randomUUID().toString());
	}
	
	/*
	@SuppressWarnings("unused")///
	private static void generateSystemId(){
		// update , never reach here
		// only reach here for very narrow chances  (android 2.2 , no wifi , no bluetooth)
		// this always return sth.
		String fp = String.format("%s/%s/%s/%s:%s/%s/%s:%s/%s/%d-%s-%s-%s-%s",
				Build.BRAND,
				Build.PRODUCT,
				Build.DEVICE,
				Build.BOARD,
				Build.VERSION.RELEASE,
				Build.ID,
				Build.VERSION.INCREMENTAL,
				Build.TYPE,
				Build.TAGS,
				Build.TIME,
				Build.DISPLAY,Build.HOST,Build.MANUFACTURER,Build.MODEL);
		
		_debugLog(fp);
		if(null!=fp){
			_openUdid = Md5(fp);
		}
	}
	*/

}
