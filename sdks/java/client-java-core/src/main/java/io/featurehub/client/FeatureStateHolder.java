package io.featurehub.client;

import io.featurehub.sse.model.FeatureValueType;

import java.math.BigDecimal;

public interface FeatureStateHolder {
  String getKey();

  String getString();

  Boolean getBoolean();

  BigDecimal getNumber();

  String getRawJson();

  <T> T getJson(Class<T> type);

  boolean isSet();

  FeatureValueType getType();

  void addListener(FeatureListener listener);
}
