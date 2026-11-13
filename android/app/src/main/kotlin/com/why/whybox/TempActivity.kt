package com.why.whybox

import android.app.Activity
import android.os.Bundle
import com.why.whybox.extensions.wrapAction
import com.why.whybox.widget.HomeWidgetRenderer
import com.why.whybox.widget.HomeWidgets

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> GlobalState.handleStart()
            wrapAction("STOP") -> GlobalState.handleStop()
            wrapAction("CHANGE") -> GlobalState.handleToggle()
            wrapAction(HomeWidgetRenderer.REFRESH_ACTION) -> HomeWidgets.refresh(this)
        }
        finishAndRemoveTask()
    }
}
