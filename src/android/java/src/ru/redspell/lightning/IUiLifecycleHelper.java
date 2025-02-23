package ru.redspell.lightning;

import android.os.Bundle;
import android.content.Intent;

public interface IUiLifecycleHelper {
	void onCreate(Bundle savedInstanceState);
	void onStart();
	void onResume();
	void onActivityResult(int requestCode, int resultCode, Intent data);
	void onSaveInstanceState(Bundle outState);
	void onPause();
	void onStop();
	void onDestroy();
}
