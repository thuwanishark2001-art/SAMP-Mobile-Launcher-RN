import { StackActions } from '@react-navigation/native';
import React, { useCallback } from 'react';
import { setAlertUpdatingMode } from '../../actions/alertActions';
import { setInitial } from '../../actions/appActions';
import { useAppDispatch } from '../../hooks/useAppDispatch';
import { useAppSelector } from '../../hooks/useAppSelector';
import { navigationRef } from '../../routers/RootNavigation';
import { selectAlertUpdateMode } from '../../selectors/alertSelectors';
import { fetchInitialApp } from '../../thunks/appThunks';
import { nameFileRecursion } from '../../thunks/loaderThunks';
import { fetchModeInverseSetting } from '../../thunks/settingsThunks';
import { AlertLauncher } from '../AlertLauncher/AlertLauncher';

export const AlertUpdateMode = React.memo(() => {
  const show = useAppSelector(selectAlertUpdateMode);
  const dispatch = useAppDispatch();

  const onCancelPressed = useCallback(() => {
    dispatch(nameFileRecursion());
    dispatch(fetchModeInverseSetting());
    dispatch(setAlertUpdatingMode(false));
  }, []);

  const onConfirmPressed = useCallback(() => {
    dispatch(setAlertUpdatingMode(false));
    dispatch(setInitial({ initial: false }));
    dispatch(fetchInitialApp());
    return navigationRef.current?.dispatch(StackActions.replace('Initiation'));
  }, []);

  return (
    <AlertLauncher
      show={show}
      title="Attention"
      useNativeDriver={true}
      closeOnTouchOutside={false}
      closeOnHardwareBackPress={false}
      message="You need to download the missing game files."
      showConfirmButton={true}
      confirmText="Cancel"
      showCancelButton={true}
      cancelText="Download"
      onCancelPressed={onConfirmPressed}
      onConfirmPressed={onCancelPressed}
    />
  );
});
