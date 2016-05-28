// @flow
import React, {Component} from 'react'
import {Box, Icon, Button} from './'
import {globalStyles, globalColors} from '../styles/style-guide'

import type {Props} from './confirm'

class Confirm extends Component<void, Props, void> {
  render () {
    return (
      <Box style={{...stylesContainer, ...backgroundColorThemed[this.props.theme]}}>
        <Icon style={{...stylesClose, ...stylesCloseThemed[this.props.theme]}} type='fa-close' onClick={this.props.onCancel} />
        {this.props.children}
        <Box style={{...globalStyles.flexBoxRow, marginTop: 32}}>
          <Button type='Secondary' style={cancelButtonThemed[this.props.theme]} labelStyle={cancelButtonLabelThemed[this.props.theme]} onClick={this.props.onCancel} label='Cancel' />
          <Button type={this.props.danger ? 'Danger' : 'Primary'} onClick={this.props.onSubmit} label={this.props.submitLabel} />
        </Box>
      </Box>
    )
  }
}

const stylesContainer = {
  ...globalStyles.flexBoxColumn,
  padding: 64,
  alignItems: 'center',
  justifyContent: 'center',
  position: 'relative'
}

const backgroundColorThemed = {
  'public': {
    backgroundColor: globalColors.white
  },
  'private': {
    backgroundColor: globalColors.darkBlue3
  }
}

const cancelButtonThemed = {
  'public': {},
  'private': {
    backgroundColor: globalColors.blue_30
  }
}

const cancelButtonLabelThemed = {
  'public': {},
  'private': {
    color: globalColors.white
  }
}

const stylesClose = {
  ...globalStyles.clickable,
  position: 'absolute',
  right: 16,
  top: 16
}

const stylesCloseThemed = {
  'public': {
    color: globalColors.black_20
  },
  'private': {
    color: globalColors.white_40
  }
}

export default Confirm
