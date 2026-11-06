package com.google.mediapipe.tasks.core.logging;

import android.content.Context;

/**
 * Privacy replacement for the pinned MediaPipe Tasks factory.
 * The upstream TasksStatsDummyLogger is intentionally a no-op. This source
 * class has the exact binary name/signature used by TaskRunner; the Gradle
 * task removes the upstream factory and remote logger implementation first.
 */
public final class TasksStatsLoggerFactory {
  private TasksStatsLoggerFactory() {}

  public static TasksStatsLogger create(Context context, String taskName, String runningMode) {
    return TasksStatsDummyLogger.create(context, taskName, runningMode);
  }
}
