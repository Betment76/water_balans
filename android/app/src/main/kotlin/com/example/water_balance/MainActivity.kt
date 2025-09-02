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
import android.content.Intent

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
                    val position = call.argument<String>("position") ?: "default"
                    showBanner(slotId, position)
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

    private fun showBanner(slotId: Int, position: String) {
        try {
            runOnUiThread {
                // Создаем баннер
                bannerView = MyTargetView(this).apply {
                    setSlotId(slotId)
                    setAdSize(MyTargetView.AdSize.ADSIZE_320x50)
                    
                    // Обработчики событий
                    listener = object : MyTargetViewListener {
                        override fun onLoad(myTargetView: MyTargetView) {
                            Log.d("MyTarget", "Баннер успешно загружен: slotId=$slotId, position=$position")
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

                // Добавляем баннер на экран с учетом позиции
                addBannerToScreen(position)
                
                // Загружаем рекламу
                bannerView?.load()
            }
        } catch (e: Exception) {
            Log.e("MyTarget", "Ошибка показа баннера: ${e.message}")
        }
    }

    private fun addBannerToScreen(position: String) {
        bannerContainer = FrameLayout(this).apply {
            val layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                
                when (position) {
                    "under_appbar" -> {
                        // Получаем высоту статус бара
                        val statusBarHeight = resources.getDimensionPixelSize(
                            resources.getIdentifier("status_bar_height", "dimen", "android")
                        )
                        
                        // Используем фиксированное значение для AppBar (56dp)
                        val density = resources.displayMetrics.density
                        val appBarHeight = (56 * density).toInt()
                        
                        // Размещаем баннер прямо под AppBar
                        topMargin = statusBarHeight + appBarHeight + (8 * density).toInt() // добавляем небольшой отступ
                        
                        Log.d("BannerPosition", 
                            "under_appbar - StatusBar: $statusBarHeight, AppBar: $appBarHeight, Total: $topMargin")
                    }
                    "top" -> {
                        // Размещаем баннер в самом верху (под статус баром)
                        val statusBarHeight = resources.getDimensionPixelSize(
                            resources.getIdentifier("status_bar_height", "dimen", "android")
                        )
                        topMargin = statusBarHeight
                        
                        Log.d("BannerPosition", "top - StatusBar: $statusBarHeight")
                    }
                    else -> {
                        // Дефолтная позиция - под AppBar
                        val statusBarHeight = resources.getDimensionPixelSize(
                            resources.getIdentifier("status_bar_height", "dimen", "android")
                        )
                        val density = resources.displayMetrics.density
                        val appBarHeight = (56 * density).toInt()
                        topMargin = statusBarHeight + appBarHeight
                        
                        Log.d("BannerPosition", 
                            "default - StatusBar: $statusBarHeight, AppBar: $appBarHeight, Total: $topMargin")
                    }
                }
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