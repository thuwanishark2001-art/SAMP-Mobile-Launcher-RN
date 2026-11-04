import { useNavigation } from '@react-navigation/native';
import React, { useCallback } from 'react';
import { useDispatch } from 'react-redux';
import { setAlertUserName } from '../../actions/alertActions';
import { useAppSelector } from '../../hooks/useAppSelector';
import { selectAlertUserName } from '../../selectors/alertSelectors';
import { AlertLauncher } from '../AlertLauncher/AlertLauncher';

export const AlertUserName = React.memo(() => {
  const show = useAppSelector(selectAlertUserName);
  const navigation = useNavigation();
  const dispatch = useDispatch();

  const onPressCancel = useCallback(async () => {
    dispatch(setAlertUserName(false));
    return navigation.jumpTo('Settings');
  }, []);

  const onConfirmPressed = useCallback(() => {
    dispatch(setAlertUserName(false));
  }, []);

  return (
    <AlertLauncher
      show={show}
      title="Tip"
      useNativeDriver={true}
      closeOnTouchOutside={false}
      closeOnHardwareBackPress={false}
      message="Set your Firstname_Lastname in Settings first"
      showConfirmButton={true}
      confirmText="Settings"
      showCancelButton={true}
      cancelText="Close"
      onCancelPressed={onConfirmPressed}
      onConfirmPressed={onPressCancel}
    />
  );
});
