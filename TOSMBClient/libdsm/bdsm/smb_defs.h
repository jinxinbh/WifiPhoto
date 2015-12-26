/*****************************************************************************
 *  __________________    _________  _____            _____  .__         ._.
 *  \______   \______ \  /   _____/ /     \          /  _  \ |__| ____   | |
 *   |    |  _/|    |  \ \_____  \ /  \ /  \        /  /_\  \|  _/ __ \  | |
 *   |    |   \|    `   \/        /    Y    \      /    |    |  \  ___/   \|
 *   |______  /_______  /_______  \____|__  / /\   \____|__  |__|\___ |   __
 *          \/        \/        \/        \/  )/           \/        \/   \/
 *
 * This file is part of liBDSM. Copyright © 2014-2015 VideoLabs SAS
 *
 * Author: Julien 'Lta' BALLET <contact@lta.io>
 *
 * liBDSM is released under LGPLv2.1 (or later) and is also available
 * under a commercial license.
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/**
 * @file smb_defs.h
 * @brief SMB usefull constants
 */

#ifndef __BSDM_SMB_DEFS_H_
#define __BSDM_SMB_DEFS_H_

#define SMB_DEFAULT_BUFSIZE     (8192)

enum
{
    /// SMB with Direct-TCP connection (OSX supports only this)
    SMB_TRANSPORT_TCP           = 1,
    /// SMB with Netbios over TCP (older mechanism)
    SMB_TRANSPORT_NBT           = 2
};

//-----------------------------------------------------------------------------/
// SMB Session states
//-----------------------------------------------------------------------------/
enum
{
    /// Error state, there was an error somewhere
    SMB_STATE_ERROR             = -1,
    /// The SMB session has just been created
    SMB_STATE_NEW               = 0,
    /// A Netbios session has been successfully established.
    SMB_STATE_NETBIOS_OK        = 1,
    /// Dialect was successfully negotiated
    SMB_STATE_DIALECT_OK        = 2,
    /// Session Authentication was successfull, you can become nasty
    SMB_STATE_SESSION_OK        = 3
};

//-----------------------------------------------------------------------------/
// smb_fseek() operations
//-----------------------------------------------------------------------------/
// smb_fseek operations
enum
{
    /// Set the read pointer at the given position
    SMB_SEEK_SET                = 0,
    /// Adjusts the read pointer relatively to the actual position
    SMB_SEEK_CUR                = 1
};

enum smb_session_supports_what
{
    SMB_SESSION_XSEC            = 0,
};

//-----------------------------------------------------------------------------/
// File access rights (used when smb_open() files)
//-----------------------------------------------------------------------------/
/// Flag for smb_file_open. Request right for reading
#define SMB_MOD_READ            (1 << 0)
/// Flag for smb_file_open. Request right for writing
#define SMB_MOD_WRITE           (1 << 1)
/// Flag for smb_file_open. Request right for appending
#define SMB_MOD_APPEND          (1 << 2)
/// Flag for smb_file_open. Request right for extended read (?)
#define SMB_MOD_READ_EXT        (1 << 3)
/// Flag for smb_file_open. Request right for extended write (?)
#define SMB_MOD_WRITE_EXT       (1 << 4)
/// Flag for smb_file_open. Request right for execution (?)
#define SMB_MOD_EXEC            (1 << 5)
/// Flag for smb_file_open. Request right for child removal (?)
#define SMB_MOD_RMCHILD         (1 << 6)
/// Flag for smb_file_open. Request right for reading file attributes
#define SMB_MOD_READ_ATTR       (1 << 7)
/// Flag for smb_file_open. Request right for writing file attributes
#define SMB_MOD_WRITE_ATTR      (1 << 8)
/// Flag for smb_file_open. Request right for removing file
#define SMB_MOD_RM              (1 << 16)
/// Flag for smb_file_open. Request right for reading ACL
#define SMB_MOD_READ_CTL        (1 << 17)
/// Flag for smb_file_open. Request right for writing ACL
#define SMB_MOD_WRITE_DAC       (1 << 18)
/// Flag for smb_file_open. Request right for changing owner
#define SMB_MOD_CHOWN           (1 << 19)
/// Flag for smb_file_open. (??)
#define SMB_MOD_SYNC            (1 << 20)
/// Flag for smb_file_open. (??)
#define SMB_MOD_SYS             (1 << 24)
/// Flag for smb_file_open. (??)
#define SMB_MOD_MAX_ALLOWED     (1 << 25)
/// Flag for smb_file_open. Request all generic rights (??)
#define SMB_MOD_GENERIC_ALL     (1 << 28)
/// Flag for smb_file_open. Request generic exec right (??)
#define SMB_MOD_GENERIC_EXEC    (1 << 29)
/// Flag for smb_file_open. Request generic read right (??)
#define SMB_MOD_GENERIC_READ    (1 << 30)
/// Flag for smb_file_open. Request generic write right (??)
#define SMB_MOD_GENERIC_WRITE   (1 << 31)
/**
 * @brief Flag for smb_file_open. Default R/W mode
 * @details A few flags OR'ed
 */
#define SMB_MOD_RW              (SMB_MOD_READ | SMB_MOD_WRITE | SMB_MOD_APPEND \
                                | SMB_MOD_READ_EXT | SMB_MOD_WRITE_EXT \
                                | SMB_MOD_READ_ATTR | SMB_MOD_WRITE_ATTR \
                                | SMB_MOD_READ_CTL )
/**
 * @brief Flag for smb_file_open. Default R/O mode
 * @details A few flags OR'ed
 */
#define SMB_MOD_RO              (SMB_MOD_READ | SMB_MOD_READ_EXT \
                                | SMB_MOD_READ_ATTR | SMB_MOD_READ_CTL )

#endif
