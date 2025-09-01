package com.example.water_balance

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.my.target.ads.MyTargetView
import com.my.target.ads.MyTargetView.MyTargetViewListener
import com.my.target.common.models.IAdLoadingError
import android.widget.FrameLayout
import android.view.Gravity
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mytarget_ads"
    private var bannerView: MyTargetView? = null
    private var bannerContainer: FrameLayout? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    initializeMyTarget()
                    result.success(null)
                }
                "showBanner" -> {
                    val slotId = call.argument<Int>("slotId") ?: 0
                    showBanner(slotId)
                    result.success(null)
                }
                "hideBanner" -> {
                    hideBanner()
                    result.success(null)
                }
                "isAdAvailable" -> {
                    result.success(true) // Для теста всегда true
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeMyTarget() {
        try {
            // Инициализация MyTarget SDK
            Log.d("MyTarget", "Инициализация MyTarget SDK")
        } catch (e: Exception) {
            Log.e("MyTarget", "Ошибка инициализации: ${e.message}")
        }
    }

    private fun showBanner(slotId: Int) {
        try {
            runOnUiThread {
                // Создаем баннер
                bannerView = MyTargetView(this).apply {
                    setSlotId(slotId)
                    setAdSize(MyTargetView.AdSize.ADSIZE_320x50)
                    
                    // Обработчики событий
                    listener = object : MyTargetViewListener {
                        override fun onLoad(myTargetView: MyTargetView) {
                            Log.d("MyTarget", "Баннер успешно загружен: slotId=$slotId")
                        }

                        override fun onNoAd(error: IAdLoadingError, myTargetView: MyTargetView) {
                            Log.e("MyTarget", "Нет рекламы: ${error.message}")
                            Log.e("MyTarget", "Код ошибки: ${error.code}")
                            Log.e("MyTarget", "Slot ID: $slotId")
                        }

                        override fun onClick(myTargetView: MyTargetView) {
                            Log.d("MyTarget", "Клик по баннеру")
                        }

                        override fun onShow(myTargetView: MyTargetView) {
                            Log.d("MyTarget", "Баннер показан")
                        }
                    }
                }

                // Добавляем баннер на экран (вверху)
                addBannerToScreen()
                
                // Загружаем рекламу
                bannerView?.load()
            }
        } catch (e: Exception) {
            Log.e("MyTarget", "Ошибка показа баннера: ${e.message}")
        }
    }

    private fun addBannerToScreen() {
        bannerContainer = FrameLayout(this).apply {
            val layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                // Размещаем баннер вверху по центру
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                topMargin = 100 // Отступ от верха под бар
            }
            
            bannerView?.let { addView(it, layoutParams) }
        }
        
        // Добавляем контейнер на экран
        findViewById<FrameLayout>(android.R.id.content)?.addView(bannerContainer)
    }

    private fun hideBanner() {
        runOnUiThread {
            bannerContainer?.let {
                findViewById<FrameLayout>(android.R.id.content)?.removeView(it)
            }
            bannerView?.destroy()
            bannerView = null
            bannerContainer = null
            Log.d("MyTarget", "Баннер скрыт")
        }
    }

    override fun onDestroy() {
        hideBanner()
        super.onDestroy()
    }
}
