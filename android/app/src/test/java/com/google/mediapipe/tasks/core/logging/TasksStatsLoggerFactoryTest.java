package com.google.mediapipe.tasks.core.logging;

import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class TasksStatsLoggerFactoryTest {
  @Test
  public void createUsesOnlyMediaPipeNoOpLogger() {
    TasksStatsLogger logger = TasksStatsLoggerFactory.create(null, "vision/face_landmarker", "IMAGE");

    assertTrue(logger instanceof TasksStatsDummyLogger);
    logger.logSessionStart();
    logger.recordCpuInputArrival(1L);
    logger.recordInvocationEnd(2L);
    logger.logSessionEnd();
  }
}
