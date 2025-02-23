package com.sec.android.iap.lib.listener;

import com.sec.android.iap.lib.vo.ErrorVo;
import com.sec.android.iap.lib.vo.PurchaseVo;

/**
 * Callback Interface to be invoked when payment has been finished.
 */
public interface OnPaymentListener
{
    /**
     * Callback method to be invoked when payment has been finished.
     * There is return data for result of financial transaction whenever it was successful or failed.
     */
    void onPayment( ErrorVo _errorVO, PurchaseVo _purchaseVO );
}
